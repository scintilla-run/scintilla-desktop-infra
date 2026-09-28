use serde_json::{Map, Value};
use std::{collections::BTreeSet, env, fs, path::Path};

const MAX_BYTES: u64 = 64 * 1024;
const EXPECTED_REPOSITORY: &str = "scintilla-run/scintilla-desktop-infra";
const EXPECTED_ROLE: &str = "desktop_infra";
const AUTHORITY_REPOSITORY: &str = "ORESoftware/ores-common-desktop-infra";
const AUTHORITY_PR: u64 = 9;
const EXPECTED_LIFECYCLE: &[&str] = &[
    "prepare",
    "validate",
    "compile_build_generation",
    "stage",
    "health_check",
    "atomic_activate",
    "bounded_drain",
    "commit",
];
const EXPECTED_ROLE_REQUIREMENTS: &[&str] = &[
    "build_stage_activate",
    "health_before_activate",
    "stable_ingress_only",
    "no_dynamic_routes_in_edge_proxy",
];

fn object<'a>(value: &'a Value, name: &str) -> Result<&'a Map<String, Value>, String> {
    value
        .as_object()
        .ok_or_else(|| format!("{name} must be an object"))
}

fn exact_keys(object: &Map<String, Value>, expected: &[&str], name: &str) -> Result<(), String> {
    let actual: BTreeSet<&str> = object.keys().map(String::as_str).collect();
    let expected: BTreeSet<&str> = expected.iter().copied().collect();
    if actual == expected {
        Ok(())
    } else {
        Err(format!(
            "{name} keys mismatch: got {actual:?}, expected {expected:?}"
        ))
    }
}

fn field<'a>(object: &'a Map<String, Value>, key: &str) -> Result<&'a Value, String> {
    object
        .get(key)
        .ok_or_else(|| format!("missing field: {key}"))
}

fn string<'a>(object: &'a Map<String, Value>, key: &str) -> Result<&'a str, String> {
    field(object, key)?
        .as_str()
        .ok_or_else(|| format!("{key} must be a string"))
}

fn boolean(object: &Map<String, Value>, key: &str) -> Result<bool, String> {
    field(object, key)?
        .as_bool()
        .ok_or_else(|| format!("{key} must be a boolean"))
}

fn integer(object: &Map<String, Value>, key: &str) -> Result<u64, String> {
    field(object, key)?
        .as_u64()
        .ok_or_else(|| format!("{key} must be an unsigned integer"))
}

fn strings<'a>(object: &'a Map<String, Value>, key: &str) -> Result<Vec<&'a str>, String> {
    field(object, key)?
        .as_array()
        .ok_or_else(|| format!("{key} must be an array"))?
        .iter()
        .map(|item| {
            item.as_str()
                .ok_or_else(|| format!("{key} must contain only strings"))
        })
        .collect()
}

fn require(condition: bool, message: &str) -> Result<(), String> {
    condition.then_some(()).ok_or_else(|| message.to_owned())
}

fn validate(document: &Value) -> Result<(), String> {
    let root = object(document, "root")?;
    exact_keys(
        root,
        &[
            "schema",
            "consumer",
            "authority",
            "lifecycle",
            "rollback",
            "request_semantics",
            "routing",
            "middleware",
            "role_requirements",
            "verification",
        ],
        "root",
    )?;
    require(
        string(root, "schema")? == "ores.desktop-generation-consumer/v1",
        "unexpected schema",
    )?;

    let consumer = object(field(root, "consumer")?, "consumer")?;
    exact_keys(consumer, &["repository", "role"], "consumer")?;
    require(
        string(consumer, "repository")? == EXPECTED_REPOSITORY
            && string(consumer, "role")? == EXPECTED_ROLE,
        "consumer identity drifted",
    )?;

    let authority = object(field(root, "authority")?, "authority")?;
    exact_keys(
        authority,
        &["repository", "revision", "pull_request"],
        "authority",
    )?;
    require(
        string(authority, "repository")? == AUTHORITY_REPOSITORY
            && integer(authority, "pull_request")? == AUTHORITY_PR,
        "authority identity drifted",
    )?;
    let revision = string(authority, "revision")?;
    require(
        revision.len() == 40
            && revision
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte)),
        "authority revision must be exactly 40 lowercase hexadecimal characters",
    )?;

    require(
        strings(root, "lifecycle")?.as_slice() == EXPECTED_LIFECYCLE,
        "lifecycle drifted",
    )?;

    let rollback = object(field(root, "rollback")?, "rollback")?;
    exact_keys(
        rollback,
        &["required_before_commit", "retain_previous_generation"],
        "rollback",
    )?;
    require(
        boolean(rollback, "required_before_commit")?
            && boolean(rollback, "retain_previous_generation")?,
        "rollback invariants changed",
    )?;

    let requests = object(field(root, "request_semantics")?, "request_semantics")?;
    exact_keys(
        requests,
        &[
            "new_requests",
            "existing_requests",
            "generation_identity_required",
        ],
        "request_semantics",
    )?;
    require(
        string(requests, "new_requests")? == "active_generation"
            && string(requests, "existing_requests")? == "pinned_generation"
            && boolean(requests, "generation_identity_required")?,
        "request semantics changed",
    )?;

    let routing = object(field(root, "routing")?, "routing")?;
    exact_keys(
        routing,
        &[
            "dynamic_route_authority",
            "edge_proxy_route_authority",
            "stable_edges",
        ],
        "routing",
    )?;
    require(
        string(routing, "dynamic_route_authority")? == "shared_router_generation"
            && !boolean(routing, "edge_proxy_route_authority")?
            && strings(routing, "stable_edges")?.as_slice() == ["nginx", "haproxy", "caddy"],
        "routing invariants changed",
    )?;

    let middleware = object(field(root, "middleware")?, "middleware")?;
    exact_keys(
        middleware,
        &[
            "parameter_changes",
            "code_changes",
            "beam_code_reload_requires_drain_or_otp_proof",
        ],
        "middleware",
    )?;
    require(
        string(middleware, "parameter_changes")? == "atomic_generation_swap"
            && string(middleware, "code_changes")? == "wasm_generation_or_proven_beam_upgrade"
            && boolean(middleware, "beam_code_reload_requires_drain_or_otp_proof")?,
        "middleware invariants changed",
    )?;

    require(
        strings(root, "role_requirements")?.as_slice() == EXPECTED_ROLE_REQUIREMENTS,
        "role requirements changed",
    )?;

    let verification = object(field(root, "verification")?, "verification")?;
    exact_keys(
        verification,
        &[
            "shared_conformance_required",
            "product_e2e_required",
            "promotion_state",
        ],
        "verification",
    )?;
    require(
        boolean(verification, "shared_conformance_required")?
            && boolean(verification, "product_e2e_required")?
            && string(verification, "promotion_state")? == "candidate",
        "verification invariants changed",
    )
}

fn run(path: &Path) -> Result<(), String> {
    let metadata =
        fs::symlink_metadata(path).map_err(|error| format!("stat {}: {error}", path.display()))?;
    require(
        metadata.file_type().is_file(),
        "contract path must be a regular file, not a symlink or directory",
    )?;
    require(metadata.len() <= MAX_BYTES, "contract exceeds 64 KiB")?;
    let bytes = fs::read(path).map_err(|error| format!("read {}: {error}", path.display()))?;
    let document: Value =
        serde_json::from_slice(&bytes).map_err(|error| format!("invalid JSON: {error}"))?;
    validate(&document)
}

fn main() {
    let mut args = env::args_os().skip(1);
    let Some(path) = args.next() else {
        eprintln!("usage: scintilla-generation-contract-validator <contract.json>");
        std::process::exit(2);
    };
    if args.next().is_some() {
        eprintln!("expected exactly one contract path");
        std::process::exit(2);
    }

    match run(Path::new(&path)) {
        Ok(()) => println!("generation contract OK"),
        Err(error) => {
            eprintln!("generation contract validation failed: {error}");
            std::process::exit(2);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn checked_in_document() -> Value {
        serde_json::from_str(include_str!("../../../ores-generation-contract.json")).unwrap()
    }

    #[test]
    fn checked_in_contract_validates() {
        assert!(validate(&checked_in_document()).is_ok());
    }

    #[test]
    fn unknown_root_fields_fail_closed() {
        let mut document = checked_in_document();
        document
            .as_object_mut()
            .unwrap()
            .insert("unexpected".to_owned(), Value::Bool(true));
        assert!(validate(&document).is_err());
    }

    #[test]
    fn uppercase_or_short_authority_revisions_are_rejected() {
        for revision in ["ABCDEF", "C98AEE842535429BC07B5E4437A2FB84D8F00D25"] {
            let mut document = checked_in_document();
            document["authority"]["revision"] = Value::String(revision.to_owned());
            assert!(validate(&document).is_err());
        }
    }
}
