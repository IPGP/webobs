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
                        values = line.rstrip("\n").split(sep, maxsplit=nvals)
                        values.extend([""] * (nvals - len(values)))
                        for i in range(1, nvals):
                            k1, k2 = values[0].strip(), keys[i]
                            config[(k1, k2)] = values[i]
        return config
    except OSError as osex:
        raise
