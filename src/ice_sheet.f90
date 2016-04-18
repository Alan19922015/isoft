!
!  ice_sheet.f90
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

module ice_sheet_mod
  !* Author: Christopher MacMackin
  !  Date: April 2016
  !  License: GPLv3
  !
  ! Provides a concrete implementation of the [[glacier]] type, using
  ! a vertically integrated model of an ice sheet.
  !
  use glacier_mod
  use cheb1d_fields_mod
  implicit none
  private

  type, extends(glacier), public :: ice_sheet
    !* Author: Chris MacMackin
    !  Date: April 2016
    !
    ! A concrete implementation of the [[glacier]] type, using a vertically
    ! integrated model of an ice sheet. This model is 1-dimensional only.
    !
    private
    type(cheb1d_scalar_field) :: thickness 
      !! Thickness of ice sheet, $h$
    type(cheb1d_vector_field) :: velocity  
      !! Flow velocity of ice sheet, $\vec{u}$
  contains
    procedure :: t => sheet_dt
    procedure :: local_error => sheet_local_error
    procedure :: integrand_multiply_integrand => sheet_m_sheet
    procedure :: integrand_multiply_real => sheet_m_real
    procedure :: real_multiply_integrand => real_m_sheet
    procedure :: add => sheet_add
    procedure :: sub => sheet_sub
    procedure :: assign_integrand => sheet_assign
    procedure :: ice_thickness => sheet_thickness
    procedure :: ice_density => sheet_density
    procedure :: ice_temperature => sheet_temperature
    procedure :: residual => sheet_residual
    procedure :: update => sheet_update
  end type ice_sheet

contains
  
  function sheet_dt(self,t)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Computes the derivative of the ice sheet with respect to time. As
    ! the only property of the ice which explicitely changes with time is
    ! the ice thickness, that will be the only portion of the returned type
    ! which actually corresponds to the derivative.
    !
    class(ice_sheet), intent(in) :: self
    real(r8), intent(in)         :: t
      !! Time at which to evaluate the derivative
    class(integrand), allocatable :: sheet_dt
      !! The time rate of change of the ice sheet. Has dynamic type
      !! [[ice_sheet]].
  end function sheet_dt

  function sheet_local_error(lhs, rhs) result(error)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Calculates a real scalar to represent the absolute difference between
    ! two ice_sheet objects. `rhs` must be a a [[ice_sheet]] object, or a
    ! runtime error will occur.
    !
    class(ice_sheet), intent(in) :: lhs
      !! Self
    class(integrand), intent(in) :: rhs
      !! The ice sheet object which is being compared against.
    real(r8) :: error
      !! The scalar representation of the absolute difference between these
      !! two ice shelves.
  end function sheet_local_error

  function sheet_m_sheet(lhs, rhs) result(product)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Multiplies one ice sheet object by another. That is to say, it 
    ! performs element-wise multiplication of the state vectors 
    ! representing the two arguments. `rhs` must be an [[ice_sheet]]
    ! object, or a runtime error will occur.
    !
    class(ice_sheet), intent(in)  :: lhs
      !! Self
    class(integrand), intent(in)  :: rhs
      !! The ice sheet object being multiplied by.
    class(integrand), allocatable :: product
      !! The product of the two arguments. Has dynamic type [[ice_sheet]].
  end function sheet_m_sheet

  function sheet_m_real(lhs, rhs) result(product)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Multiplies one ice sheet object by a scalar. That is to say, it 
    ! performs element-wise multiplication of the state vector 
    ! representing the ice sheet.
    !
    class(ice_sheet), intent(in)  :: lhs
      !! Self
    real(r8), intent(in)          :: rhs
      !! The scalar being multiplied by.
    class(integrand), allocatable :: product
      !! The product of the two arguments. Has dynamic type [[ice_sheet]].
  end function sheet_m_real

  function real_m_sheet(lhs, rhs) result(product)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Multiplies one ice sheet object by a scalar. That is to say, it 
    ! performs element-wise multiplication of the state vector 
    ! representing the ice sheet.
    !
    real(r8), intent(in)          :: lhs
      !! The scalar being multiplied by.
    class(ice_sheet), intent(in) :: rhs
      !! Self
    class(integrand), allocatable :: product
      !! The product of the two arguments. Has dynamic type [[ice_sheet]].
  end function real_m_sheet

  function sheet_add(lhs, rhs) result(sum)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Adds one ice sheet object to another. That is to say, it performs
    ! element-wise addition of the state vectors representing the two
    ! arguments. `rhs` must be an [[ice_sheet]] object, or a runtime
    ! error will occur.
    !
    class(ice_sheet), intent(in) :: lhs
      !! Self
    class(integrand), intent(in)  :: rhs
      !! The ice sheet object being added.
    class(integrand), allocatable :: sum
      !! The sum of the two arguments. Has dynamic type [[ice_sheet]].
  end function sheet_add

  function sheet_sub(lhs, rhs) result(difference)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Subtracts one ice sheet object from another. That is to say, it 
    ! performs element-wise addition of the state vectors representing 
    ! the two arguments. `rhs` must be a a [[ice_sheet]] object, or a
    ! runtime error will occur.
    !
    class(ice_sheet), intent(in) :: lhs
      !! Self
    class(integrand), intent(in)  :: rhs
      !! The ice sheet object being subtracted.
    class(integrand), allocatable :: difference
      !! The difference of the two arguments. Has dynamic type [[ice_sheet]].
  end function sheet_sub

  subroutine sheet_assign(lhs, rhs)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Assigns the `rhs` ice sheet to this, `lhs`, one. All components
    ! will be the same following the assignment.
    !
    class(ice_sheet), inent(inout) :: lhs
      !! Self
    class(integrand), intent(in)   :: rhs
      !! The object to be assigned. Must have dynamic type [[ice_sheet]],
      !! or a runtime error will occur.
  end subroutine sheet_assign

  function sheet_thickness(this) result(thickness)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the thickness of the ice shelf across its domain.
    !
    class(basal_surface), intent(in) :: this
    class(scalar_field), allocatable :: thickness !! The ice thickness.
  end function sheet_thickness

  function sheet_density(this) result(density)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the density of the ice in the sheet, which is assumed to be
    ! uniform across its domain.
    !
    class(basal_surface), intent(in) :: this
    real(r8)                         :: density !! The ice density.
  end function sheet_density

  function sheet_temperature(this) result(temperature)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the density of the ice in the sheet, which is assumed to be
    ! uniform across its domain.
    !
    class(basal_surface), intent(in) :: this
    real(r8)                         :: temperature !! The ice density.
  end function sheet_temperature

  function sheet_residual(this, melt_rate, basal_drag_parameter, water_density)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the residual when the current state of the glacier is run
    ! through the system of equations describing it. The residual takes the
    ! form of a 1D array, with each element respresenting the residual for
    ! one of the equations in the system.
    !
    class(basal_surface), intent(in)    :: this
    class(scalar_field), intent(in)     :: melt_rate
      !! Thickness of the ice above the glacier.
    class(scalar_field), intent(in)     :: basal_drag_parameter
      !! A paramter, e.g. coefficient of friction, needed to calculate the
      !! drag on basal surface of the glacier.
    class(scalar_field), intent(in)     :: water_density
      !! The density of the water below the glacier.
    real(r8), dimension(:), allocatable :: residual
      !! The residual of the system of equations describing the glacier.
  end function sheet_residual

  subroutine sheet_update(this, state_vector, time)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Updates the state of the ice sheet from its state vector. The state
    ! vector is a real array containing the value of each of the ice sheet's
    ! properties at each of the locations on the grid used in descretization.
    !
    class(basal_surface), intent(inout) :: this
    real(r8), dimension(:), intent(in)  :: state_vector
      !! A real array containing the data describing the state of the
      !! glacier.
    real(r8), intent(in), optional      :: time
      !! The time at which the glacier is in this state. If not present
      !! then assumed to be same as previous value passed.
  end subroutine sheet_update

end module ice_sheet_mod
