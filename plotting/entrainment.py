#!/usr/bin/env python
#
#  entrainment.py
#  This file is part of ISOFT.
#  
#  Copyright 2017 Chris MacMackin <cmacmackin@gmail.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  

'''Contains classes for calculating the entrainment rate of the plume
using different parameterisations.
'''

import numpy as np
import calculus

class Jenkins1991Entrainment(object):
    '''A class representing the entrainment formulation used by Jenkins et
    al. (1991).

    coefficient
        The coefficient used in the entrainment calculation
    size
        The number of Chebyshev modes in the field
    lower
        The lower boundary of the field domain
    upper
        The upper boundary of the field domain
    '''

    def __init__(this, coefficient, size, lower=0.0, upper=1.0):
        this.coef = coefficient
        this.diff = calculus.Differentiator(size, lower, upper)

    def __call__(this, U, D, b):
        return this.coef * np.linalg.norm(U, axis=-1) * np.abs(this.diff(b))
        

