!
!  ice_shelf.f90
!  This file is part of ISOFT.
!  
!  Copyright 2016 Chris MacMackin <cmacmackin@gmail.com>
!  
!  This program is free software; you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation; either version 2 of the License, or
!  (at your option) any later version.
!  
!  This program is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.
!  
!  You should have received a copy of the GNU General Public License
!  along with this program; if not, write to the Free Software
!  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
!  MA 02110-1301, USA.
!  

module ice_shelf_mod
  !* Author: Christopher MacMackin
  !  Date: April 2016
  !  License: GPLv3
  !
  ! Provides a concrete implementation of the [[glacier]] type, using
  ! a vertically integrated model of an ice shelf.
  !
  use iso_fortran_env, only: r8 => real64
  use foodie, only: integrand
  use glacier_mod, only: glacier
  use factual_mod, only: scalar_field, cheb1d_scalar_field, cheb1d_vector_field
  implicit none
  private

  type, extends(glacier), public :: ice_shelf
    !* Author: Chris MacMackin
    !  Date: April 2016
    !
    ! A concrete implementation of the [[glacier]] type, using a vertically
    ! integrated model of an ice shelf. This model is 1-dimensional only.
    !
    private
    type(cheb1d_scalar_field) :: thickness 
      !! Thickness of ice shelf, $h$
    type(cheb1d_vector_field) :: velocity  
      !! Flow velocity of ice shelf, $\vec{u}$
  contains
    procedure            :: t => shelf_dt
    procedure            :: local_error => shelf_local_error
    procedure            :: integrand_multiply_integrand => shelf_m_shelf
    procedure            :: integrand_multiply_real => shelf_m_real
    procedure, pass(rhs) :: real_multiply_integrand => real_m_shelf
    procedure            :: add => shelf_add
    procedure            :: sub => shelf_sub
    procedure            :: assign_integrand => shelf_assign
    procedure            :: ice_thickness => shelf_thickness
    procedure            :: ice_density => shelf_density
    procedure            :: ice_temperature => shelf_temperature
    procedure            :: residual => shelf_residual
    procedure            :: update => shelf_update
  end type ice_shelf

contains
  
  function shelf_dt(self,t)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Computes the derivative of the ice shelf with respect to time. As
    ! the only property of the ice which explicitely changes with time is
    ! the ice thickness, that will be the only portion of the returned type
    ! which actually corresponds to the derivative.
    !
    class(ice_shelf), intent(in)   :: self
    real(r8), intent(in), optional :: t
      !! Time at which to evaluate the derivative
    class(integrand), allocatable  :: shelf_dt
      !! The time rate of change of the ice shelf. Has dynamic type
      !! [[ice_shelf]].
  end function shelf_dt

  function shelf_local_error(lhs, rhs) result(error)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Calculates a real scalar to represent the absolute difference between
    ! two ice_shelf objects. `rhs` must be a a [[ice_shelf]] object, or a
    ! runtime error will occur.
    !
    class(ice_shelf), intent(in) :: lhs
      !! Self
    class(integrand), intent(in) :: rhs
      !! The ice shelf object which is being compared against.
    real(r8) :: error
      !! The scalar representation of the absolute difference between these
      !! two ice shelves.
  end function shelf_local_error

  function shelf_m_shelf(lhs, rhs) result(product)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Multiplies one ice shelf object by another. That is to say, it 
    ! performs element-wise multiplication of the state vectors 
    ! representing the two arguments. `rhs` must be an [[ice_shelf]]
    ! object, or a runtime error will occur.
    !
    class(ice_shelf), intent(in)  :: lhs
      !! Self
    class(integrand), intent(in)  :: rhs
      !! The ice shelf object being multiplied by.
    class(integrand), allocatable :: product
      !! The product of the two arguments. Has dynamic type [[ice_shelf]].
  end function shelf_m_shelf

  function shelf_m_real(lhs, rhs) result(product)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Multiplies one ice shelf object by a scalar. That is to say, it 
    ! performs element-wise multiplication of the state vector 
    ! representing the ice shelf.
    !
    class(ice_shelf), intent(in)  :: lhs
      !! Self
    real(r8), intent(in)          :: rhs
      !! The scalar being multiplied by.
    class(integrand), allocatable :: product
      !! The product of the two arguments. Has dynamic type [[ice_shelf]].
  end function shelf_m_real

  function real_m_shelf(lhs, rhs) result(product)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Multiplies one ice shelf object by a scalar. That is to say, it 
    ! performs element-wise multiplication of the state vector 
    ! representing the ice shelf.
    !
    real(r8), intent(in)          :: lhs
      !! The scalar being multiplied by.
    class(ice_shelf), intent(in)  :: rhs
      !! Self
    class(integrand), allocatable :: product
      !! The product of the two arguments. Has dynamic type [[ice_shelf]].
  end function real_m_shelf

  function shelf_add(lhs, rhs) result(sum)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Adds one ice shelf object to another. That is to say, it performs
    ! element-wise addition of the state vectors representing the two
    ! arguments. `rhs` must be an [[ice_shelf]] object, or a runtime
    ! error will occur.
    !
    class(ice_shelf), intent(in)  :: lhs
      !! Self
    class(integrand), intent(in)  :: rhs
      !! The ice shelf object being added.
    class(integrand), allocatable :: sum
      !! The sum of the two arguments. Has dynamic type [[ice_shelf]].
  end function shelf_add

  function shelf_sub(lhs, rhs) result(difference)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Subtracts one ice shelf object from another. That is to say, it 
    ! performs element-wise addition of the state vectors representing 
    ! the two arguments. `rhs` must be a a [[ice_shelf]] object, or a
    ! runtime error will occur.
    !
    class(ice_shelf), intent(in)  :: lhs
      !! Self
    class(integrand), intent(in)  :: rhs
      !! The ice shelf object being subtracted.
    class(integrand), allocatable :: difference
      !! The difference of the two arguments. Has dynamic type [[ice_shelf]].
  end function shelf_sub

  subroutine shelf_assign(lhs, rhs)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Assigns the `rhs` ice shelf to this, `lhs`, one. All components
    ! will be the same following the assignment.
    !
    class(ice_shelf), intent(inout) :: lhs
      !! Self
    class(integrand), intent(in)    :: rhs
      !! The object to be assigned. Must have dynamic type [[ice_shelf]],
      !! or a runtime error will occur.
  end subroutine shelf_assign

  function shelf_thickness(this) result(thickness)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the thickness of the ice shelf across its domain.
    !
    class(ice_shelf), intent(in)     :: this
    class(scalar_field), allocatable :: thickness !! The ice thickness.
  end function shelf_thickness

  function shelf_density(this) result(density)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the density of the ice in the shelf, which is assumed to be
    ! uniform across its domain.
    !
    class(ice_shelf), intent(in) :: this
    real(r8)                     :: density !! The ice density.
  end function shelf_density

  function shelf_temperature(this) result(temperature)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the density of the ice in the shelf, which is assumed to be
    ! uniform across its domain.
    !
    class(ice_shelf), intent(in) :: this
    real(r8)                     :: temperature !! The ice density.
  end function shelf_temperature

  function shelf_residual(this, melt_rate, basal_drag_parameter, &
                          water_density) result(residual) 
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the residual when the current state of the glacier is run
    ! through the system of equations describing it. The residual takes the
    ! form of a 1D array, with each element respresenting the residual for
    ! one of the equations in the system.
    !
    class(ice_shelf), intent(in)        :: this
    class(scalar_field), intent(in)     :: melt_rate
      !! Thickness of the ice above the glacier.
    class(scalar_field), intent(in)     :: basal_drag_parameter
      !! A paramter, e.g. coefficient of friction, needed to calculate the
      !! drag on basal surface of the glacier.
    class(scalar_field), intent(in)     :: water_density
      !! The density of the water below the glacier.
    real(r8), dimension(:), allocatable :: residual
      !! The residual of the system of equations describing the glacier.
  end function shelf_residual

  subroutine shelf_update(this, state_vector, time)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Updates the state of the ice shelf from its state vector. The state
    ! vector is a real array containing the value of each of the ice shelf's
    ! properties at each of the locations on the grid used in discretization.
    !
    class(ice_shelf), intent(inout)     :: this
    real(r8), dimension(:), intent(in)  :: state_vector
      !! A real array containing the data describing the state of the
      !! glacier.
    real(r8), intent(in), optional      :: time
      !! The time at which the glacier is in this state. If not present
      !! then assumed to be same as previous value passed.
  end subroutine shelf_update

end module ice_shelf_mod