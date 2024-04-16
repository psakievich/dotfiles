from spack.main import SpackCommand

arch = SpackCommand("arch")

def detector(name):
    platform, _, _  = arch().split("-")
    if name == platform:
        return True
    return False
