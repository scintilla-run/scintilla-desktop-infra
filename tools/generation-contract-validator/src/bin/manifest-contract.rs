use serde_json::{json, Value};
use std::{
    collections::HashSet,
    env, fs,
    path::{Path, PathBuf},
};

const SUCCESS_MESSAGE: &str = "PASS: desktop manifest/control-plane contract";
const FORBIDDEN_SECRET_MARKERS: &[&str] = &["api_token", "access_token", "private_key", "password"];

#[derive(Clone)]
struct Documents {
    example: Value,
    control: Value,
    lock: Value,
    appliance: Value,
    runtime_template: Value,
    compose_source: String,
}

fn read_json(root: &Path, relative: &str) -> Result<Value, String> {
    let path = root.join(relative);
    let source = fs::read_to_string(&path)
        .map_err(|error| format!("cannot read {}: {error}", path.display()))?;
    serde_json::from_str(&source)
        .map_err(|error| format!("invalid JSON in {}: {error}", path.display()))
}

fn load_documents(root: &Path) -> Result<Documents, String> {
    let compose_path = root.join(".ores-compose.yaml");
    let compose_source = fs::read_to_string(&compose_path)
        .map_err(|error| format!("cannot read {}: {error}", compose_path.display()))?;

    Ok(Documents {
        example: read_json(root, "manifests/local-runtime.example.json")?,
        control: read_json(root, "manifests/control-plane.example.json")?,
        lock: read_json(root, "components.lock.json")?,
        appliance: read_json(root, "appliance.json")?,
        runtime_template: read_json(root, "runtime/desktop-manifest.example.json")?,
        compose_source,
    })
}

fn is_sha(value: &str) -> bool {
    value.len() == 40
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn is_truthy(value: Option<&Value>) -> bool {
    match value {
        None | Some(Value::Null) => false,
        Some(Value::Bool(value)) => *value,
        Some(Value::Number(value)) => value
            .as_i64()
            .map(|number| number != 0)
            .or_else(|| value.as_u64().map(|number| number != 0))
            .or_else(|| value.as_f64().map(|number| number != 0.0))
            .unwrap_or(false),
        Some(Value::String(value)) => !value.is_empty(),
        Some(Value::Array(value)) => !value.is_empty(),
        Some(Value::Object(value)) => !value.is_empty(),
    }
}

fn valid_worker_id(value: &str) -> bool {
    (1..=128).contains(&value.len())
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
}

fn quoted(value: &str) -> String {
    format!("'{}'", value.replace('\\', "\\\\").replace('\'', "\\'"))
}

fn validate_documents(documents: &Documents) -> Vec<String> {
    let mut errors = Vec::new();
    let example = &documents.example;
    let control = &documents.control;
    let lock = &documents.lock;
    let appliance = &documents.appliance;
    let runtime_template = &documents.runtime_template;

    let daemon_sha = appliance
        .get("components")
        .and_then(Value::as_array)
        .and_then(|components| {
            components.iter().find(|component| {
                component.get("name").and_then(Value::as_str) == Some("desktop-daemon")
            })
        })
        .and_then(|component| component.get("rev"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let locked_ref = lock
        .get("components")
        .and_then(|components| components.get("desktop_daemon"))
        .and_then(|component| component.get("ref"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let compose_shas: Vec<&str> = documents
        .compose_source
        .lines()
        .filter_map(|line| line.strip_prefix("  commit: "))
        .filter(|candidate| is_sha(candidate))
        .collect();

    if !is_sha(daemon_sha) {
        errors.push("daemon appliance revision must be an exact immutable SHA".to_owned());
    }
    if compose_shas.len() != 1 || compose_shas.first().copied() != Some(daemon_sha) {
        errors.push("daemon compose source revision must match appliance pin".to_owned());
    }
    if locked_ref != daemon_sha {
        errors.push("components lock daemon ref must match appliance pin".to_owned());
    }
    if !documents
        .compose_source
        .contains("[\"cargo\", \"build\", \"--release\", \"--locked\"]")
    {
        errors.push("daemon compose build must use cargo --locked".to_owned());
    }

    if example.get("schema").and_then(Value::as_str) != Some("scintilla.desktop-runtime/v1") {
        errors.push("local runtime schema id must be scintilla.desktop-runtime/v1".to_owned());
    }
    if example.get("runtime_kind").and_then(Value::as_str) != Some("scintilla-single-beam") {
        errors.push("runtime_kind must be scintilla-single-beam".to_owned());
    }
    if runtime_template.get("schema").and_then(Value::as_str)
        != Some("scintilla.desktop-runtime/v1")
    {
        errors.push("renderable runtime template must use scintilla.desktop-runtime/v1".to_owned());
    }
    if runtime_template.get("runtime_kind").and_then(Value::as_str)
        != Some("scintilla-single-beam")
    {
        errors.push("renderable runtime template must use scintilla-single-beam".to_owned());
    }
    let template_program = runtime_template
        .get("ingress")
        .and_then(|ingress| ingress.get("command"))
        .and_then(|command| command.get("program"));
    if template_program.is_none() || template_program.is_some_and(Value::is_null) {
        errors.push("renderable runtime template must use daemon ingress.command shape".to_owned());
    }
    if appliance
        .get("host")
        .and_then(|host| host.get("daemon_listen"))
        .and_then(Value::as_str)
        != Some("127.0.0.1:8765")
    {
        errors.push("appliance daemon_listen must be 127.0.0.1:8765".to_owned());
    }
    if appliance
        .get("host")
        .and_then(|host| host.get("public_origin"))
        .and_then(Value::as_str)
        != Some("http://127.0.0.1:8091")
    {
        errors.push("appliance public_origin must match ingress 127.0.0.1:8091".to_owned());
    }

    let ingress_program = example
        .get("ingress")
        .and_then(|ingress| ingress.get("command"))
        .and_then(|command| command.get("program"))
        .and_then(Value::as_str);
    if !ingress_program.is_some_and(|program| !program.trim().is_empty()) {
        errors.push("ingress.command.program must be a non-empty argv program".to_owned());
    }

    let mut ids = HashSet::new();
    if let Some(workers_value) = example.get("workers") {
        if let Some(workers) = workers_value.as_array() {
            for worker in workers {
                if !worker.is_object() {
                    errors.push("worker entry must be an object".to_owned());
                    continue;
                }
                let worker_id = worker.get("id").and_then(Value::as_str).unwrap_or("");
                if !valid_worker_id(worker_id) {
                    errors.push(format!("invalid worker id: {}", quoted(worker_id)));
                }
                if !ids.insert(worker_id.to_owned()) {
                    errors.push(format!("duplicate worker id: {}", quoted(worker_id)));
                }
                let mode = worker.get("mode").and_then(Value::as_str);
                if !matches!(mode, Some("host" | "container")) {
                    errors.push(format!("unsupported worker mode for {}", quoted(worker_id)));
                }
                if mode == Some("host")
                    && !is_truthy(
                        worker
                            .get("command")
                            .and_then(|command| command.get("program")),
                    )
                {
                    errors.push(format!(
                        "host worker {} requires command.program",
                        quoted(worker_id)
                    ));
                }
                if mode == Some("container") && !is_truthy(worker.get("image")) {
                    errors.push(format!("container worker {} requires image", quoted(worker_id)));
                }
            }
        } else {
            errors.push("workers must be an array".to_owned());
        }
    }

    if control.get("protocol").and_then(Value::as_str) != Some("scintilla.local-control/v1") {
        errors.push("control-plane protocol must be scintilla.local-control/v1".to_owned());
    }
    let mut kinds = HashSet::new();
    if let Some(clients) = control.get("clients").and_then(Value::as_array) {
        for entry in clients {
            if let Some(kind) = entry.get("kind").and_then(Value::as_str) {
                kinds.insert(kind);
            }
        }
    }
    for required in ["cli", "rust_desktop", "flutter_desktop", "flutter_mobile", "infra"] {
        if !kinds.contains(required) {
            errors.push(format!("control-plane example is missing {required}"));
        }
    }

    if lock.get("schema").and_then(Value::as_str) != Some("scintilla.desktop-components-lock/v1") {
        errors.push("components lock schema mismatch".to_owned());
    }

    let serialized = serde_json::to_string(example).unwrap_or_default().to_lowercase();
    for forbidden in FORBIDDEN_SECRET_MARKERS {
        if serialized.contains(forbidden) {
            errors.push(format!(
                "example manifest must not contain secret field '{}'",
                forbidden
            ));
        }
    }

    errors
}

fn main() {
    if env::args_os().len() != 1 {
        eprintln!("expected no arguments");
        std::process::exit(2);
    }

    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
    let documents = match load_documents(&root) {
        Ok(documents) => documents,
        Err(error) => {
            eprintln!("FAIL: {error}");
            std::process::exit(1);
        }
    };
    let errors = validate_documents(&documents);
    if errors.is_empty() {
        println!("{SUCCESS_MESSAGE}");
    } else {
        for error in errors {
            eprintln!("FAIL: {error}");
        }
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn root() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
    }

    fn documents() -> Documents {
        load_documents(&root()).expect("checked-in manifest fixtures must parse")
    }

    fn has_error(errors: &[String], expected: &str) -> bool {
        errors.iter().any(|error| error == expected)
    }

    #[test]
    fn checked_in_contract_passes_with_stable_cli_message() {
        assert!(validate_documents(&documents()).is_empty());
        assert_eq!(SUCCESS_MESSAGE, "PASS: desktop manifest/control-plane contract");
    }

    #[test]
    fn invalid_schema_fails_closed() {
        let mut docs = documents();
        docs.example["schema"] = json!("unexpected");
        assert!(has_error(
            &validate_documents(&docs),
            "local runtime schema id must be scintilla.desktop-runtime/v1"
        ));
    }

    #[test]
    fn duplicate_worker_ids_fail_closed() {
        let mut docs = documents();
        docs.example["workers"] = json!([
            {"id": "duplicate", "mode": "host", "command": {"program": "worker"}},
            {"id": "duplicate", "mode": "host", "command": {"program": "worker"}}
        ]);
        assert!(validate_documents(&docs)
            .iter()
            .any(|error| error == "duplicate worker id: 'duplicate'"));
    }

    #[test]
    fn malformed_worker_ids_fail_closed() {
        let mut docs = documents();
        docs.example["workers"] = json!([
            {"id": "bad/id", "mode": "host", "command": {"program": "worker"}}
        ]);
        assert!(validate_documents(&docs)
            .iter()
            .any(|error| error == "invalid worker id: 'bad/id'"));
    }

    #[test]
    fn missing_control_client_fails_closed() {
        let mut docs = documents();
        docs.control["clients"] = json!([]);
        assert!(has_error(
            &validate_documents(&docs),
            "control-plane example is missing cli"
        ));
    }

    #[test]
    fn secret_markers_fail_closed() {
        let mut docs = documents();
        docs.example["password"] = json!("test-only");
        assert!(has_error(
            &validate_documents(&docs),
            "example manifest must not contain secret field 'password'"
        ));
    }

    #[test]
    fn appliance_lock_and_compose_pins_must_match() {
        let mut docs = documents();
        docs.lock["components"]["desktop_daemon"]["ref"] = json!("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        assert!(has_error(
            &validate_documents(&docs),
            "components lock daemon ref must match appliance pin"
        ));
    }

    #[test]
    fn malformed_appliance_sha_fails_closed() {
        let mut docs = documents();
        let components = docs.appliance["components"].as_array_mut().unwrap();
        let daemon = components
            .iter_mut()
            .find(|component| component["name"] == "desktop-daemon")
            .unwrap();
        daemon["rev"] = json!("not-a-sha");
        assert!(has_error(
            &validate_documents(&docs),
            "daemon appliance revision must be an exact immutable SHA"
        ));
    }

    #[test]
    fn duplicate_compose_pins_fail_closed() {
        let mut docs = documents();
        let sha = docs.appliance["components"]
            .as_array()
            .unwrap()
            .iter()
            .find(|component| component["name"] == "desktop-daemon")
            .unwrap()["rev"]
            .as_str()
            .unwrap()
            .to_owned();
        docs.compose_source.push_str(&format!("\n  commit: {sha}\n"));
        assert!(has_error(
            &validate_documents(&docs),
            "daemon compose source revision must match appliance pin"
        ));
    }

    #[test]
    fn unlocked_build_fails_closed() {
        let mut docs = documents();
        docs.compose_source = docs.compose_source.replace(
            "[\"cargo\", \"build\", \"--release\", \"--locked\"]",
            "[\"cargo\", \"build\", \"--release\"]",
        );
        assert!(has_error(
            &validate_documents(&docs),
            "daemon compose build must use cargo --locked"
        ));
    }

    #[test]
    fn null_runtime_template_program_fails_closed() {
        let mut docs = documents();
        docs.runtime_template["ingress"]["command"]["program"] = Value::Null;
        assert!(has_error(
            &validate_documents(&docs),
            "renderable runtime template must use daemon ingress.command shape"
        ));
    }
}
