import re


def read_clb(filename, encoding="ISO-8859-1", sep="|"):
    try:
        nvals = 0
        config = {}
        with open(filename, encoding=encoding) as fp:
            for line in fp:
                if line.startswith("=key|"):
                    keys = line[4:].rstrip("|\n").split(sep)
                    nvals = len(keys)
                    break

        if nvals > 1:
            with open(filename, encoding=encoding) as fp:
                for line in fp:
                    if re.match(r"\w+", line):
                        vals = line.rstrip("\n").split(sep, maxsplit=nvals)
                        vals.extend([""] * (nvals - len(vals)))
                        config[vals[0]] = {k: v for (k, v) in zip(keys[1:], vals[1:])}
        return config
    except OSError:
        raise
