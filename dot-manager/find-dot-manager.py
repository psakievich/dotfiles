import sys

def detector(name):
    """
    A function that will check if the supplied name/machine
    matches a known machine configuration
    """
    # dictionary that is easily extensible where key is the name we want to match
    # and the value is function that can be evaluated to test the actual system we
    # are one
    known_machines = {
        "darwin": lambda: sys.platform == "darwin",
        "linux": lambda: sys.platform == "linux",
    }

    if name in known_machines:
        return known_machines[name]()
    else:
        return False
