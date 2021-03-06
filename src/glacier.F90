!
!  glacier.f90
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

#ifdef DEBUG
#define pure 
#define elemental 
#endif

module glacier_mod
  !* Author: Christopher MacMackin
  !  Date: April 2016
  !  License: GPLv3
  !
  ! Provides an abstract type to represent large masses of ice, such
  ! as ice sheets and ice shelves.
  !
  use iso_fortran_env, only: r8 => real64
  !use foodie, only: integrand
  use factual_mod, only: scalar_field, vector_field
  use nitsol_mod!, only: nitsol, dummy_jacv, ddot, dnrm2
  use hdf5, only: hid_t
  use penf, only: str
  use logger_mod, only: logger => master_logger
  implicit none
  private

  character(len=12), parameter, public :: hdf_type_attr = 'glacier_type'

  type, abstract, public :: glacier
    !* Author: Christopehr MacMackin
    !  Date: April 2016
    !
    ! An abstract data type which represents large masses of ice, such
    ! as ice shelves and ice sheets.
    !
  contains
    procedure(get_scalar), deferred   :: ice_thickness
      !! Returns the thickness of the ice in the glacier across the domain.
    procedure(get_r8), deferred       :: ice_density
      !! Returns the density of the ice, which is assumed to be uniform.
    procedure(get_r8), deferred       :: ice_temperature
      !! Returns the temperature of the ice, which is assumed to be uniform.
    procedure(get_residual), deferred :: residual
      !! Computes the residual of the system of equations describing the
      !! glacier.
    procedure(precond), deferred      :: precondition
      !! Applies a preconditioner to the passed state vector.
    procedure(solve_vel), deferred    :: solve_velocity
      !! Solves for the velocity field using the current thickness.
    procedure(setter), deferred       :: update
      !! Sets the state of the glacier.
    procedure(time_setter), deferred  :: set_time
      !! Sets the time record for this glacier.
    procedure(get_i), deferred        :: data_size
      !! Returns the number of elements in the glacier's state vector
    procedure(get_r81d), deferred     :: state_vector
      !! Returns the glacier's state vector, a 1D array with all necessary 
      !! data to describe its state.
    procedure(read_dat), deferred     :: read_data
      !! Read the glacier data from an HDF5 file on the disc.
    procedure(write_dat), deferred    :: write_data
      !! Writes the data describing the glacier to the disc as an HDF5 file.
    procedure(t_step), deferred       :: time_step
      !! Calculates the appropriate time step for integration.
    procedure(assign_ice), private, deferred :: assign
      !! Copies the data from one glacier into another. This is only
      !! needed due to a bug in gfortran which means that the
      !! intrinsic assignment for glacier types is not using the
      !! appropriate defined assignment for the field components.
    generic                           :: assignment(=) => assign
    procedure                         :: integrate => glacier_integrate
      !! Performs a time-step of the integration, taking the state of
      !! the glacier to the specified time using the provided
      !! melt-rate data.
    procedure                         :: integrate_layers => glacier_integrate_layers
      !! Dummy routine which can be over-ridden to integrate internal
      !! layers of the glacier to the specified time.
  end type glacier

  abstract interface
    function get_scalar(this) result(property)
      import :: glacier
      import :: scalar_field
      class(glacier), intent(in)   :: this
      class(scalar_field), pointer :: property
        !! The value of whatever property of the glacier is being returned.
    end function get_scalar
    
!$    function get_vector(this) result(property)
!$      import :: glacier
!$      import :: vector_field
!$      class(glacier), intent(in)       :: this
!$      class(vector_field), allocatable :: property
!$        !! The value of whatever property of the glacier is being returned.
!$    end function get_vector
    
    pure function get_r8(this) result(property)
      import :: glacier
      import :: r8
      class(glacier), intent(in) :: this
      real(r8)                   :: property
        !! The value of whatever property of the glacier is being returned.
    end function get_r8

    function get_residual(this, previous_states, melt_rate, &
                          basal_drag_parameter, water_density) result(residual)
      import :: glacier
      import :: scalar_field
      import :: r8
      class(glacier), intent(in)               :: this
      class(glacier), dimension(:), intent(in) :: previous_states
        !! The states of the glacier in the previous time steps. The
        !! first element of the array should be the most recent. The
        !! default implementation will only make use of the most
        !! recent state, but the fact that this is an array allows
        !! overriding methods to use older states for higher-order
        !! integration methods.
      class(scalar_field), intent(in)          :: melt_rate
        !! Thickness of the ice above the glacier
      class(scalar_field), intent(in)          :: basal_drag_parameter
        !! A paramter, e.g. coefficient of friction, needed to
        !! calculate the drag on basal surface of the glacier.
      real(r8), intent(in)                     :: water_density
        !! The density of the water below the glacier
      real(r8), dimension(:), allocatable      :: residual
        !! The residual of the system of equations describing the
        !! glacier
    end function get_residual

    function precond(this, previous_states, melt_rate, &
                     basal_drag_parameter, water_density, &
                     delta_state) result(preconditioned)
      import :: glacier
      import :: scalar_field
      import :: r8
      class(glacier), intent(inout)            :: this
      class(glacier), dimension(:), intent(in) :: previous_states
        !! The states of the glacier in the previous time steps. The
        !! first element of the array should be the most recent. The
        !! default implementation will only make use of the most
        !! recent state, but the fact that this is an array allows
        !! overriding methods to use older states for higher-order
        !! integration methods.
      class(scalar_field), intent(in)          :: melt_rate
        !! Thickness of the ice above the glacier
      class(scalar_field), intent(in)          :: basal_drag_parameter
        !! A paramter, e.g. coefficient of friction, needed to
        !! calculate the drag on basal surface of the glacier.
      real(r8), intent(in)                     :: water_density
        !! The density of the water below the glacier
      real(r8), dimension(:), intent(in)       :: delta_state
        !! The change to the state vector which is being
        !! preconditioned.
      real(r8), dimension(:), allocatable      :: preconditioned
        !! The result of applying the preconditioner to `delta_state`.
    end function precond

    subroutine solve_vel(this, basal_drag, success)
      import :: glacier
      import :: scalar_field
      class(glacier), intent(inout)   :: this
      class(scalar_field), intent(in) :: basal_drag
        !! A paramter, e.g. coefficient of friction, needed to calculate
        !! the drag on basal surface of the glacier.
      logical, intent(out)            :: success
        !! True if the integration is successful, false otherwise
    end subroutine solve_vel

    function get_r81d(this) result(state_vector)
      import :: glacier
      import :: r8
      class(glacier), intent(in)          :: this
      real(r8), dimension(:), allocatable :: state_vector
        !! The state vector of the glacier
    end function get_r81d

    subroutine setter(this, state_vector)
      import :: glacier
      import :: r8
      class(glacier), intent(inout)      :: this
      real(r8), dimension(:), intent(in) :: state_vector
        !! A real array containing the data describing the state of the
        !! glacier.
    end subroutine setter

    subroutine time_setter(this, time)
      import :: glacier
      import :: r8
      class(glacier), intent(inout) :: this
      real(r8), intent(in)          :: time
        !! The time at which the glacier is in the present state.
    end subroutine time_setter

    pure function get_i(this) result(property)
      import :: glacier
      class(glacier), intent(in) :: this
      integer                    :: property
        !! The value of whatever property of the glacier is being returned.
    end function get_i

    subroutine read_dat(this,file_id,group_name,error)
      import :: glacier
      import :: hid_t
      class(glacier), intent(inout) :: this
      integer(hid_t), intent(in)    :: file_id
        !! The identifier for the HDF5 file/group from which the data
        !! will be read.
      character(len=*), intent(in)  :: group_name
        !! The name of the group in the HDF5 file from which to read
        !! glacier's data.
      integer, intent(out)          :: error
        !! Flag indicating whether routine ran without error. If no
        !! error occurs then has value 0.
    end subroutine read_dat

    subroutine write_dat(this,file_id,group_name,error)
      import :: glacier
      import :: hid_t
      class(glacier), intent(in)   :: this
      integer(hid_t), intent(in)   :: file_id
        !! The identifier for the HDF5 file/group in which this data is
        !! meant to be written.
      character(len=*), intent(in) :: group_name
        !! The name to give the group in the HDF5 file storing the
        !! glacier's data.
      integer, intent(out)         :: error
        !! Flag indicating whether routine ran without error. If no
        !! error occurs then has value 0.
    end subroutine write_dat

    function t_step(this)
      import :: r8
      import :: glacier
      class(glacier), intent(in) :: this
      real(r8) :: t_step
        !! A time step which will allow integration of the ice shelf
        !! without causing numerical instability.
    end function t_step

    subroutine assign_ice(this, rhs)
      import :: glacier
      class(glacier), intent(out) :: this
      class(glacier), intent(in)  :: rhs
    end subroutine assign_ice
  end interface
 
#ifdef DEBUG
#undef pure
#undef elemental
#endif
  
  abstract interface
    pure function thickness_func(location) result(thickness)
      !* Author: Chris MacMackin
      !  Date: April 2016
      !
      ! Abstract interface for function providing the [[glacier]] thickness
      ! when a concrete object is being instantiated.
      !
      import :: r8
      real(r8), dimension(:), intent(in) :: location
        !! The position $\vec{x}$ at which to compute the thickness
      real(r8) :: thickness
        !! The thickness of the glacier at `location`
    end function thickness_func

    pure function velocity_func(location) result(velocity)
      !* Author: Chris MacMackin
      !  Date: July 2016
      !
      ! Abstract interface for function providing the [[glacier]] velocity
      ! when a concrete object is being instantiated.
      !
      import :: r8
      real(r8), dimension(:), intent(in) :: location
        !! The position $\vec{x}$ at which to compute the thickness
      real(r8), dimension(:), allocatable :: velocity
        !! The velocity vector of the ice in the glacier at `location`
    end function velocity_func
  end interface

#ifdef DEBUG
#define pure 
#define elemental 
#endif
  
  public :: thickness_func, velocity_func

contains

  subroutine glacier_integrate(this, old_states, basal_melt, basal_drag, &
                               water_density, time, success)
    !* Author: Chris MacMackin
    !  Date: November 2016
    !
    ! Integrates the glacier's state to `time`. This is done using the
    ! NITSOL package of iterative Krylov solvers. If a different
    ! algorithm for the integration is desired, then this method may
    ! be overridden in the concrete implementations of the glacier
    ! type.
    !
    class(glacier), intent(inout)            :: this
    class(glacier), dimension(:), intent(in) :: old_states
      !! Previous states of the glacier, with the most recent one
      !! first.
    class(scalar_field), intent(in)          :: basal_melt
      !! The melt rate that the bottom of the glacier experiences
      !! during this time step.
    class(scalar_field), intent(in)          :: basal_drag
      !! A paramter, e.g. coefficient of friction, needed to calculate
      !! the drag on basal surface of the glacier.
    real(r8), intent(in)                     :: water_density
      !! The density of the water below the glacier.
    real(r8), intent(in)                     :: time
      !! The time to which the glacier should be integrated
    logical, intent(out)                     :: success
      !! True if the integration is successful, false otherwise

    logical                                   :: first_call
    integer, save                             :: nval, kdmax = 20
    real(r8), dimension(:), allocatable       :: state
    integer, dimension(10)                    :: input
    integer, dimension(6)                     :: info
    real(r8), dimension(:), allocatable, save :: work
    real(r8), dimension(1)                    :: real_param
    integer, dimension(1)                     :: int_param
    integer                                   :: flag

    call basal_melt%guard_temp(); call basal_drag%guard_temp()
    first_call = .true.
    nval = this%data_size()
    if (allocated(work)) then
      if (size(work) < nval*(kdmax+5) + kdmax*(kdmax+3)) then
        deallocate(work)
        allocate(work(nval*(kdmax+5) + kdmax*(kdmax+3)))
      end if
    else
      allocate(work(nval*(kdmax+5) + kdmax*(kdmax+3)))
    end if
    state = this%state_vector()
    call this%set_time(time)
    input = 0
    input(4) = kdmax
    input(5) = 1
    input(9) = -1
    input(10) = 3
    etafixed = 0.3_r8

#ifdef DEBUG
    call logger%debug('glacier%integrate','Calling NITSOL (nonlinear solver)')
#endif
    call nitsol(nval, state, nitsol_residual, nitsol_precondition, &
                1.e-10_r8*nval, 1.e-10_r8*nval, input, info, work, &
                real_param, int_param, flag, ddot, dnrm2)
    call this%update(state)
!!$    if (flag == 6 .and. input(9) > -1) then
!!$      input(9) = -1
!!$      call logger%trivia('glacier%integrate','Backtracking failed in NITSOL '// &
!!$                         'at simulation time '//str(time)//'. Trying again '//  &
!!$                         'without backtracking.')
!!$      call nitsol(nval, state, nitsol_residual, nitsol_precondition, &
!!$                  1.e-7_r8, 1.e-7_r8, input, info, work, real_param, &
!!$                  int_param, flag, ddot, dnrm2)
!!$    end if
#ifdef DEBUG
    call logger%debug('glacier%integrate','NITSOL required '//       &
                      trim(str(info(5)))//' nonlinear iterations '// &
                      'and '//trim(str(info(1)))//' function calls.')
#endif

    select case(flag)
    case(0)
      call logger%trivia('glacier%integrate','Integrated glacier to time '// &
                         trim(str(time)))
      success = .true.
    case(1)
      call logger%error('glacier%integrate','Reached maximum number of'// &
                        ' iterations integrating glacier')
      success = .false.
    !case(5)
    !  call logger%debug('glacier%integrate','Solution diverging. Trying '// &
    !                    'again with backtracking.')
    !  state = old_states(1)%state_vector()
    !  input(9) = 0
    !  call nitsol(nval, state, nitsol_residual, nitsol_precondition, &
    !              1.e-7_r8, 1.e-7_r8, input, info, work, real_param, &
    !              int_param, flag, ddot, dnrm2)
    !  call this%update(state)
    !  if (flag == 0) then
    !    call logger%trivia('glacier%integrate','Integrated glacier to time '// &
    !                       trim(str(time)))
    !    success = .true.
    !  else
    !    call logger%error('glacier%integrate','NITSOL failed when integrating'// &
    !                      ' glacier with error code '//trim(str(flag)))
    !    success = .false.
    !  end if
    case default
      call logger%error('glacier%integrate','NITSOL failed when integrating'// &
                        ' glacier with error code '//trim(str(flag)))
      success = .false.
    end select

    if (success) then
      call this%integrate_layers(old_states, time, success)
    end if

    call basal_melt%clean_temp(); call basal_drag%clean_temp()

  contains
    
    subroutine nitsol_residual(n, xcur, fcur, rpar, ipar, itrmf)
      !! A routine matching the interface expected by NITSOL which
      !! returns the residual for the glacier.
      integer, intent(in)                   :: n
        !! Dimension of the problem
      real(r8), dimension(n), intent(in)    :: xcur
        !! Array of length `n` containing the current \(x\) value
      real(r8), dimension(n), intent(out)   :: fcur
        !! Array of length `n` containing f(xcur) on output
      real(r8), dimension(*), intent(inout) :: rpar
        !! Parameter/work array
      integer, dimension(*), intent(inout)  :: ipar
        !! Parameter/work array
      integer, intent(out)                  :: itrmf
        !! Termination flag. 0 means normal termination, 1 means
        !! failure to produce f(xcur)

      logical :: success
      ! If this is the first call of this routine then the
      ! basal_surface object will already be in the same state as
      ! reflected in xcur
      if (first_call) then
        first_call = .false.
      else
        call this%update(xcur(1:n))
      end if
      call this%solve_velocity(basal_drag, success)
      if (.not. success) then
        itrmf = 1
        return
      end if
      fcur(1:n) = this%residual(old_states,basal_melt,basal_drag,water_density)
      !print*, fcur(1:n)
      itrmf = 0
    end subroutine nitsol_residual

    subroutine nitsol_precondition(n, xcur, fcur, ijob, v, z, rpar, ipar, itrmjv)
      !! A subroutine matching the interface expected by NITSOL, which
      !! acts as a preconditioner.
      integer, intent(in)                   :: n
        ! Dimension of the problem
      real(r8), dimension(n), intent(in)    :: xcur
        ! Array of lenght `n` containing the current $x$ value
      real(r8), dimension(n), intent(in)    :: fcur
        ! Array of lenght `n` containing the current \(f(x)\) value
      integer, intent(in)                   :: ijob
        ! Integer flat indicating which product is desired. 0
        ! indicates \(z = J\vec{v}\). 1 indicates \(z = P^{-1}\vec{v}\).
      real(r8), dimension(n), intent(in)    :: v
        ! An array of length `n` to be multiplied
      real(r8), dimension(n), intent(out)   :: z
        ! An array of length n containing the desired product on
        ! output.
      real(r8), dimension(*), intent(inout) :: rpar
        ! Parameter/work array 
      integer, dimension(*), intent(inout)  :: ipar
        ! Parameter/work array
      integer, intent(out)                  :: itrmjv
        ! Termination flag. 0 indcates normal termination, 1
        ! indicatesfailure to prodce $J\vec{v}$, and 2 indicates
        ! failure to produce \(P^{-1}\vec{v}\)
      if (ijob /= 1) then
        itrmjv = 0
        return
      end if
      z(1:n) = this%precondition(old_states, basal_melt, basal_drag, &
                                 water_density, v(1:n))
      itrmjv = 0
    end subroutine nitsol_precondition

  end subroutine glacier_integrate

  subroutine glacier_integrate_layers(this, old_states, time, success)
    !* Author: Chris MacMackin
    !  Date: September 2018
    !
    ! Dummy routine which does nothing.
    !
    class(glacier), intent(inout)            :: this
    class(glacier), dimension(:), intent(in) :: old_states
      !! Previous states of the glacier, with the most recent one
      !! first.
    real(r8), intent(in)                     :: time
      !! The time to which the glacier should be integrated
    logical, intent(out)                     :: success
      !! True if the integration is successful, false otherwise
    continue
  end subroutine glacier_integrate_layers

end module glacier_mod
