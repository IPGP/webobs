import os
import re

import pendulum

from wolib.utils import str_to_float


def read_config(filename, encoding="ISO-8859-1", sep="|"):
    config = {}

    try:
        with open(file=filename, encoding=encoding) as fp:
            for line in fp:
                if re.match(r"\w+", line):
                    key, val = line.rstrip("\n").partition(sep)[::2]
                    config[key.strip()] = val
    except OSError:
        raise

    for key, val in config.items():
        variables = re.findall(r"\${(.+?)}", val)
        for var in variables:
            if config.get(var):
                # add space before ${ for example in \bf${NAME}
                val = re.sub(r"(\w)\${", r"\1 ${", val)
                # internal variable substitution
                val = val.replace("${" + var + "}", config[var])

        if WEBOBS:
            variables = re.findall(r"\$WEBOBS{(.+?)}", val)
            for var in variables:
                if WEBOBS.get(var):
                    # webobs variable substitution
                    val = val.replace("$WEBOBS{" + var + "}", WEBOBS[var])
        config[key] = val
    return config


def print_config(config):
    for key, val in config.items():
        print(key, "->", val)


def set_clb_timestamp(clb, timezone=None):
    if timezone is None:
        timezone = pendulum.local_timezone()

    for k in clb.keys():
        dt = "T".join([clb[k].pop("DATE"), clb[k].pop("TIME")])
        try:
            clb[k]["dt"] = pendulum.parse(dt, tz=timezone).timestamp()
        except (TypeError, ValueError):
            pass
    return clb


def read_clb(filename, encoding="ISO-8859-1", sep="|"):
    config = {}
    try:
        nvals = 0
        with open(filename, encoding=encoding) as fp:
            for line in fp:
                if line.startswith("=key|"):
                    keys = line[4:].rstrip("|\n").split(sep)
                    nvals = len(keys)
                    break

        if nvals > 1:
            float_keys = ["of", "ga", "vn", "vm", "az", "la", "lo", "al"]
            float_keys.extend(["dp", "sf", "db"])
            with open(filename, encoding=encoding) as fp:
                for line in fp:
                    if re.match(r"\w+", line):
                        vals = line.rstrip("\n").split(sep, maxsplit=nvals)
                        vals.extend([""] * (nvals - len(vals)))
                        kid = int(vals[0])
                        config[kid] = {k: v for (k, v) in zip(keys[1:], vals[1:])}
                        for k in float_keys:
                            config[kid][k] = str_to_float(config[kid].get(k), nan=True)

        config = set_clb_timestamp(config)
    except OSError as err:
        print(err)
    return config


def get_out_dir(proc):
    outdir = getattr(proc, "OUTDIR", "")
    if hasattr(proc, "EVENTS"):
        outg = WEBOBS.get("PATH_OUTG_EVENTS", "")
        pout = os.path.join(outdir, outg, proc.EVENTS)
    else:
        outg = WEBOBS.get("PATH_OUTG_EXPORT", "")
        pout = os.path.join(outdir, outg)
    return pout


WEBOBS = {}
WEBOBS = read_config("/etc/webobs.d/WEBOBS.rc")
GRIDS = read_config(WEBOBS["CONF_GRIDS"])
NODES = read_config(WEBOBS["CONF_NODES"])

if __name__ == "__main__":
    # cd ~/webobs/CODE/python/superprocs
    # python3 -m wolib.config

    print("---------------------- GRIDS.rc -------------------- \n")
    print_config(GRIDS)

    print("\n-------------------- NODES.rc -------------------- \n")
    print_config(NODES)
