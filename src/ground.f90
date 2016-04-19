!
!  ground.f90
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

module ground_mod
  !* Author: Christopher MacMackin
  !  Date: April 2016
  !  License: GPLv3
  !
  ! Provides a concrete implementation of the [[basal_surface]] data type,
  ! representing solid ground.
  !
  use iso_fortran_env, only: r8 => real64
  use basal_surface_mod, only: basal_surface
  use factual_mod, only: scalar_field
  implicit none
  private

  type, extends(basal_surface), public :: ground
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! A concrete implementation of the [[basal_surface]] abstract data type,
    ! representing the ground beneath an ice sheet. At the moment this
    ! doesn't actually do anything.
    !
  contains
    procedure :: basal_melt => ground_melt
    procedure :: basal_drag_parameter => ground_drag_parameter
    procedure :: water_density => ground_water_density
    procedure :: residual => ground_residual
    procedure :: update => ground_update
  end type ground

contains

  function ground_melt(this) result(melt)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Computes and returns the melt rate at the bottom of the ice
    ! sheet due to interaction with the ground.
    !
    class(ground), intent(in)        :: this
    class(scalar_field), allocatable :: melt
      !! The melt rate at the base of the ice sheet.
  end function ground_melt

  function ground_drag_parameter(this) result(drag)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Computes and returns a quantity which may be necessary to determine
    ! the frictional drag the ground exerts on the bottom of the ice
    ! sheet. An example would be the coefficient of friction. The 
    ! description of this method is left deliberately vague so that as not
    ! to constrain how the drag is parameterized.
    !
    class(ground), intent(in)        :: this
    class(scalar_field), allocatable :: drag
      !! The value of a paramter describing the drag of the ground on the
      !! ice sheet.
  end function ground_drag_parameter

  function ground_water_density(this) result(density)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Computes and returns the density of the water beneath the ice sheet.
    ! This water would be subglacial discharge and would tend to lubricate
    ! the motion of the ice sheet. The density probably won't be important
    ! in the case of an ice sheet, but is included so that the ground data
    ! type can have the same interface as the [[plume]] data type.
    !
    class(ground), intent(in)        :: this
    class(scalar_field), allocatable :: density
      !! The density of any water at the base of the ice sheet.
  end function ground_water_density
   
  function ground_residual(this, ice_thickness, ice_density, ice_temperature) &
                                                               result(residual)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Using the current state of the ground, this computes the residual
    ! of the system of equatiosn which is used to describe the ground.
    ! The residual takes the form of a 1D array, with each element 
    ! respresenting the residual for one of the equations in the system.
    !
    class(ground), intent(in)           :: this
    class(scalar_field), intent(in)     :: ice_thickness
      !! Thickness of the ice above the ground.
    real(r8), intent(in)                :: ice_density
      !! The density of the ice above the ground, assumed uniform.
    real(r8), intent(in)                :: ice_temperature
      !! The temperature of the ice above the ground, assumed uniform.
    real(r8), dimension(:), allocatable :: residual
      !! The residual of the system of equations describing the ground.
  end function ground_residual

  subroutine ground_update(this, state_vector, time)
    !* Author: Christopher MacMackin
    !  Date: April 2016
    !
    ! Updates the state of the ground from its state vector. The state
    ! vector is a real array containing the value of each of the ground's
    ! properties at each of the locations on the grid used in discretization.
    !
    class(ground), intent(inout)       :: this
    real(r8), dimension(:), intent(in) :: state_vector
      !! A real array containing the data describing the state of the
      !! ground.
    real(r8), intent(in), optional     :: time
      !! The time at which the ground is in this state. If not
      !! present then assumed to be same as previous value passed.
  end subroutine ground_update

end module ground_mod