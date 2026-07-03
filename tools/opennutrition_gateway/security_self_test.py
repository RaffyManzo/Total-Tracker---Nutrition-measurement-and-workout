from __future__ import annotations

from app.security import validate_public_hostname, validate_search_query


def expect_rejected(callback) -> None:
    try:
        callback()
    except ValueError:
        return
    raise AssertionError("Unsafe value was accepted")


def main() -> int:
    assert validate_public_hostname("nutrition.example.com") == (
        "nutrition.example.com"
    )
    for host in (
        "localhost",
        "127.0.0.1",
        "::1",
        "gateway.local",
        "singlelabel",
        "-bad.example.com",
        "bad-.example.com",
        "bad..example.com",
        "münich.example.com",
    ):
        expect_rejected(lambda host=host: validate_public_hostname(host))

    assert validate_search_query("Greek   yogurt") == "Greek yogurt"
    assert validate_search_query("caffè latte 2%") == "caffè latte 2%"
    for query in (
        "a",
        "milk\nadmin",
        "milk\u202eadmin",
        "milk<script>",
        r"milk\..\secret",
        "milk;drop table foods",
        "https://example.com",
        "milk -- admin",
        "milk /* admin */",
        " ".join(["food"] * 13),
        "x" * 81,
    ):
        expect_rejected(lambda query=query: validate_search_query(query))

    print("OPENNUTRITION_GATEWAY_SECURITY_SELF_TEST_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
