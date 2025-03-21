import re
from datetime import datetime, timedelta


def timescale(code):
    """Return a tuple of datetime objects from a duration until now.

    Args:
        code (str): A duration until now of the form xxT, where xx is a number and
        T a letter indicating the time base among (s, n, h, d, w, m, y).
        For example, 06h for six hours, 10n for ten minutes, ...
    """
    num = re.match(r"\d+", code)
    if not num or re.search(r"\W+", code):
        print("invalid duration")
        exit()

    num = int(num[0])
    if "s" in code:
        duration = timedelta(seconds=num)
    elif "n" in code:
        duration = timedelta(minutes=num)
    elif "h" in code:
        duration = timedelta(hours=num)
    elif "d" in code:
        duration = timedelta(days=num)
    elif "w" in code:
        duration = timedelta(weeks=num)
    elif "m" in code:
        duration = timedelta(days=30 * num)
    elif "y" in code:
        duration = timedelta(days=365 * num)
    else:
        print("invalid duration")
        exit()

    end_time = datetime.now()
    start_time = end_time - duration
    return (start_time, end_time)


if __name__ == "__main__":
    (start_time, end_time) = timescale("01h")
    print(start_time)
    print(end_time)
