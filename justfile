# Check the coupling as a mechanism: entry, lock, stop, limits, keying, examples
test:
    python3 tests/test_bayonet.py

# Rewrite tests/volumes.txt after an intended geometry change
volumes:
    python3 tests/test_bayonet.py --update

# Render the README pictures into images/
images:
    openscad --render --imgsize 1200,700 --viewall --autocenter --colorscheme Tomorrow --camera 0,0,0,55,0,25,0 -D 'VIEW="halves"' -o images/halves.png images/pictures.scad
    openscad --render --imgsize 900,800 --viewall --autocenter --colorscheme Tomorrow --camera 0,0,0,75,0,-30,0 -D 'VIEW="locked_cutaway"' -o images/locked_cutaway.png images/pictures.scad
