"""Ruff-clean fixture for the goneat-tools runner Python e2e smoke test.

`goneat format --check` must exit 0 on this directory.
"""


def add(left: int, right: int) -> int:
    """Return the sum of two integers."""
    return left + right


def main() -> None:
    print(add(2, 3))


if __name__ == "__main__":
    main()
