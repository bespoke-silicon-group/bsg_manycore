# Create the ManycoreCoordinate class, a surprisingly useful wrapper
# for a tuple. Access the y and x fields using var.y and var.x
from collections import namedtuple
ManycoreCoordinate = namedtuple('ManycoreCoordinate', ['y', 'x'])
