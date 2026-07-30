"""Deliberately unformatted fixture for the runner Python e2e smoke test.

`goneat format --check` must fail on this directory for FORMAT DRIFT
("files need formatting"), never for a missing ruff executable
("tool-unavailable="). Do not reformat this file -- it is excluded from the
repository's own `goneat format` runs via `.goneatignore`.
"""
def add( left,right ):
        return left+right
def main():
     print( add(2,3) )
if __name__=="__main__":
      main()
