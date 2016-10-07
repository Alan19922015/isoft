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
  use iso_fortran_env, only: r8 => real64
  !use foodie, only: integrand
  use glacier_mod, only: glacier, thickness_func, velocity_func
  use factual_mod, only: scalar_field, vector_field, cheb1d_scalar_field, &
                         cheb1d_vector_field
  use viscosity_mod, only: abstract_viscosity
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
    real(r8)                  :: lambda
      !! The dimensionless ratio 
      !! $\lambda \equiv \frac{\rho_0m_0x_0}{\rho_iH-0u_0}$
    real(r8)                  :: chi
      !! The dimensionless ratio
      !! $\chi \equiv \frac{\rho_igh_0x_x}{2\eta_0u_0}$
    class(abstract_viscosity), allocatable :: viscosity_law
      !! An object representing the model used for ice viscosity.
  contains
!$    procedure            :: t => sheet_dt
!$    procedure            :: local_error => sheet_local_error
!$    procedure            :: integrand_multiply_integrand => sheet_m_sheet
!$    procedure            :: integrand_multiply_real => sheet_m_real
!$    procedure, pass(rhs) :: real_multiply_integrand => real_m_sheet
!$    procedure            :: add => sheet_add
!$    procedure            :: sub => sheet_sub
!$    procedure            :: assign_integrand => sheet_assign
    procedure :: ice_thickness => sheet_thickness
!$    procedure :: ice_velocity => sheet_velocity
    procedure :: ice_density => sheet_density
    procedure :: ice_temperature => sheet_temperature
    procedure :: residual => sheet_residual
    procedure :: update => sheet_update
    procedure :: data_size => sheet_data_size
    procedure :: state_vector => sheet_state_vector
  end type ice_sheet

  interface ice_sheet
    module procedure constructor
  end interface ice_sheet

contains
  
  function constructor(domain, resolution, thickness, velocity, &
                       viscosity_law, lambda, chi) result(this)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Creates a new [[ice_sheet]] object with initial conditions provided
    ! by the arguments. At present only a 1D model is supported. If
    ! information is provided for higher dimensions then it will be ignored.
    !
    real(r8), dimension(:,:), intent(in) :: domain
      !! An array containing the upper and lower limits of the domain for
      !! the ice sheet. The first index represents the dimension for which
      !! the boundaries apply. If the second index is 1 then it corresponds
      !! to the lower bound. If the second index is 2 then it corresponds to
      !! the upper bound.
    integer, dimension(:), intent(in)    :: resolution
      !! The number of data points in each dimension
    procedure(thickness_func)            :: thickness
      !! A function which calculates the initial value of the thickness of 
      !! the ice sheet at a given location.
    procedure(velocity_func)             :: velocity
      !! A function which calculates the initial value of the velocity 
      !! (vector) of the ice at a given location in an ice sheet.
    class(abstract_viscosity), intent(in) :: viscosity_law
      !! An object which calculates the viscosity of the ice.
    real(r8), intent(in)                 :: lambda
      !! The dimensionless ratio 
      !! $\lambda \equiv \frac{\rho_0m_0x_0}{\rho_iH-0u_0}$
    real(r8), intent(in)                 :: chi
      !! The dimensionless ratio
      !! $\chi \equiv \frac{\rho_igh_0x_x}{2\eta_0u_0}$
    type(ice_sheet)                      :: this
      !! An ice sheet object with its domain and initial conditions set
      !! according to the arguments of the constructor function.
  end function constructor
  
!$  function sheet_dt(self,t)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Computes the derivative of the ice sheet with respect to time. As
!$    ! the only property of the ice which explicitely changes with time is
!$    ! the ice thickness, that will be the only portion of the returned type
!$    ! which actually corresponds to the derivative.
!$    !
!$    class(ice_sheet), intent(in)   :: self
!$    real(r8), intent(in), optional :: t
!$      !! Time at which to evaluate the derivative
!$    class(integrand), allocatable  :: sheet_dt
!$      !! The time rate of change of the ice sheet. Has dynamic type
!$      !! [[ice_sheet]].
!$  end function sheet_dt
!$
!$  function sheet_local_error(lhs, rhs) result(error)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Calculates a real scalar to represent the absolute difference between
!$    ! two ice_sheet objects. `rhs` must be a a [[ice_sheet]] object, or a
!$    ! runtime error will occur.
!$    !
!$    class(ice_sheet), intent(in) :: lhs
!$      !! Self
!$    class(integrand), intent(in) :: rhs
!$      !! The ice sheet object which is being compared against.
!$    real(r8) :: error
!$      !! The scalar representation of the absolute difference between these
!$      !! two ice shelves.
!$  end function sheet_local_error
!$
!$  function sheet_m_sheet(lhs, rhs) result(product)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Multiplies one ice sheet object by another. That is to say, it 
!$    ! performs element-wise multiplication of the state vectors 
!$    ! representing the two arguments. `rhs` must be an [[ice_sheet]]
!$    ! object, or a runtime error will occur.
!$    !
!$    class(ice_sheet), intent(in)  :: lhs
!$      !! Self
!$    class(integrand), intent(in)  :: rhs
!$      !! The ice sheet object being multiplied by.
!$    class(integrand), allocatable :: product
!$      !! The product of the two arguments. Has dynamic type [[ice_sheet]].
!$  end function sheet_m_sheet
!$
!$  function sheet_m_real(lhs, rhs) result(product)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Multiplies one ice sheet object by a scalar. That is to say, it 
!$    ! performs element-wise multiplication of the state vector 
!$    ! representing the ice sheet.
!$    !
!$    class(ice_sheet), intent(in)  :: lhs
!$      !! Self
!$    real(r8), intent(in)          :: rhs
!$      !! The scalar being multiplied by.
!$    class(integrand), allocatable :: product
!$      !! The product of the two arguments. Has dynamic type [[ice_sheet]].
!$  end function sheet_m_real
!$
!$  function real_m_sheet(lhs, rhs) result(product)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Multiplies one ice sheet object by a scalar. That is to say, it 
!$    ! performs element-wise multiplication of the state vector 
!$    ! representing the ice sheet.
!$    !
!$    real(r8), intent(in)          :: lhs
!$      !! The scalar being multiplied by.
!$    class(ice_sheet), intent(in)  :: rhs
!$      !! Self
!$    class(integrand), allocatable :: product
!$      !! The product of the two arguments. Has dynamic type [[ice_sheet]].
!$  end function real_m_sheet
!$
!$  function sheet_add(lhs, rhs) result(sum)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Adds one ice sheet object to another. That is to say, it performs
!$    ! element-wise addition of the state vectors representing the two
!$    ! arguments. `rhs` must be an [[ice_sheet]] object, or a runtime
!$    ! error will occur.
!$    !
!$    class(ice_sheet), intent(in)  :: lhs
!$      !! Self
!$    class(integrand), intent(in)  :: rhs
!$      !! The ice sheet object being added.
!$    class(integrand), allocatable :: sum
!$      !! The sum of the two arguments. Has dynamic type [[ice_sheet]].
!$  end function sheet_add
!$
!$  function sheet_sub(lhs, rhs) result(difference)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Subtracts one ice sheet object from another. That is to say, it 
!$    ! performs element-wise addition of the state vectors representing 
!$    ! the two arguments. `rhs` must be a a [[ice_sheet]] object, or a
!$    ! runtime error will occur.
!$    !
!$    class(ice_sheet), intent(in)  :: lhs
!$      !! Self
!$    class(integrand), intent(in)  :: rhs
!$      !! The ice sheet object being subtracted.
!$    class(integrand), allocatable :: difference
!$      !! The difference of the two arguments. Has dynamic type [[ice_sheet]].
!$  end function sheet_sub
!$
!$  subroutine sheet_assign(lhs, rhs)
!$    !* Author: Christopher MacMackin
!$    !  Date: April 2016
!$    !
!$    ! Assigns the `rhs` ice sheet to this, `lhs`, one. All components
!$    ! will be the same following the assignment.
!$    !
!$    class(ice_sheet), intent(inout) :: lhs
!$      !! Self
!$    class(integrand), intent(in)    :: rhs
!$      !! The object to be assigned. Must have dynamic type [[ice_sheet]],
!$      !! or a runtime error will occur.
!$  end subroutine sheet_assign

  pure function sheet_thickness(this) result(thickness)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the thickness of the ice shelf across its domain.
    !
    class(ice_sheet), intent(in)     :: this
    class(scalar_field), allocatable :: thickness !! The ice thickness.
  end function sheet_thickness

  function sheet_velocity(this) result(velocity)
    !* Author: Christopher MacMackin
    !  Date: July 2016
    !
    ! Returns the velocity of the ice sheet across its domain.
    !
    class(ice_sheet), intent(in)     :: this
    class(vector_field), allocatable :: velocity !! The ice velocity.
    allocate(velocity, source=this%velocity)
  end function sheet_velocity

  pure function sheet_density(this) result(density)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the density of the ice in the sheet, which is assumed to be
    ! uniform across its domain.
    !
    class(ice_sheet), intent(in) :: this
    real(r8)                     :: density !! The ice density.
  end function sheet_density

  pure function sheet_temperature(this) result(temperature)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the density of the ice in the sheet, which is assumed to be
    ! uniform across its domain.
    !
    class(ice_sheet), intent(in) :: this
    real(r8)                     :: temperature !! The ice density.
  end function sheet_temperature

  function sheet_residual(this, previous_state, melt_rate, basal_drag_parameter, &
                          water_density) result(residual)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the residual when the current state of the glacier is run
    ! through the system of equations describing it. The residual takes the
    ! form of a 1D array, with each element respresenting the residual for
    ! one of the equations in the system.
    !
    class(ice_sheet), intent(in)        :: this
    class(glacier), intent(in)          :: previous_state
      !! The state of the ice sheet in the previous time step
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
    class(ice_sheet), intent(inout)    :: this
    real(r8), dimension(:), intent(in) :: state_vector
      !! A real array containing the data describing the state of the
      !! glacier.
    real(r8), intent(in), optional     :: time
      !! The time at which the glacier is in this state. If not present
      !! then assumed to be same as previous value passed.
  end subroutine sheet_update

  pure function sheet_data_size(this)
    !* Author: Christopher MacMackin
    !  Date: August 2016
    !
    ! Returns the number of elements in the ice sheet's state vector.
    ! This is the size of the vector returned by [[ice_sheet:residual]]
    ! and [[ice_shelf:state_vector]] and taken as an argument by 
    ! [[ice_shelf:update]].
    !
    class(ice_sheet), intent(in) :: this
    integer :: sheet_data_size
      !! The number of elements in the ice sheet's state vector.
  end function sheet_data_size

  pure function sheet_state_vector(this) result(state_vector) 
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Returns the state vector for the current state of the ice sheet. 
    ! This takes the form of a 1D array.
    !
    class(ice_sheet), intent(in)        :: this
    real(r8), dimension(:), allocatable :: state_vector
      !! The state vector describing the ice sheet.
  end function sheet_state_vector

end module ice_sheet_mod
