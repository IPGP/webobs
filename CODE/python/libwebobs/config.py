import re


def read_config(filename, encoding="ISO-8859-1", sep="|"):
    config = {}

    try:
        with open(file=filename, encoding=encoding) as fp:
            for line in fp:
                if re.match(r"\w+", line):
                    key, val = line.rstrip("\n").partition(sep)[::2]
                    config[key.strip()] = val
    except OSError as osex:
        raise

    for key, val in config.items():
        variables = re.findall(r"\${(.+?)}", val)
        for var in variables:
            if config.get(var):
                val = val.replace("${" + var + "}", config[var])
                config[key] = val

        if WEBOBS:
            variables = re.findall(r"\$WEBOBS{(.+?)}", val)
            for var in variables:
                if WEBOBS.get(var):
                    val = val.replace("$WEBOBS{" + var + "}", WEBOBS[var])
                    config[key] = val
    return config


def print_config(config):
    for key, val in config.items():
        print(key, "->", val)


WEBOBS = {}
WEBOBS = read_config("/etc/webobs.d/WEBOBS.rc")
