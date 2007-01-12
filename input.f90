!=======================================================================
!     S H E B A - Shear-wave Birefringence Analysis
!=======================================================================
!     Fortran 90/95 Source Code File
!-----------------------------------------------------------------------
!
!     PROGRAM : sheba
!     FILE    : input.f
!     AUTHOR  : James Wookey
!     PLACE   : School of Earth Sciences, University of Leeds
!     DATE    : December 2003
!     PURPOSE : Various subroutines for sheba
!     VERSION : 1.0
!     COMPLETE: No
!     COMMENTS: 
!
!-----------------------------------------------------------------------
!     This software is distributed in the hope that it will be useful,
!     but WITHOUT ANY WARRANTY; without even the implied warranty of
!     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
!-----------------------------------------------------------------------
!
!      sheba is a prototype code to implement various algorithms for
!      analysing shear-wave splitting. 
!
!-----------------------------------------------------------------------
!     Changes log
!-----------------------------------------------------------------------
!     2003-12-04     * Incept date
!     2006-08-18     * added checking for null cmpaz/cmpinc (gives a
!                      more sensible error message in that circumstance)
!=======================================================================
      subroutine read_config()
!=======================================================================
!  
!     Read SHEBA configuration files from input file
!
      use sheba_config 
      implicit none
      
      character :: dum ! just a dummy character
      character (len=80) :: fn
      
!  ** open file
      open(10,file='sheba.in',status='old',err=900)
!  ** skip header line      
      read(10,*) dum

!  ** read input parameters      
      read(10,*,err=901) fn
      config % fname_base = trim(fn) 
      read(10,*,err=901) config % comp(1) 
      read(10,*,err=901) config % comp(2) 
      read(10,*,err=901) config % comp(3) 
      read(10,*,err=901) config % imode

      if (config % imode == 0) then
         read(10,*,err=901) config % source_pol
      else
         config % source_pol = 0.0
      endif
      read(10,*,err=901) config % nwindbeg, config % nwindend
      read(10,*,err=901) config % max_tlag

!  ** read REC correction options
      read(10,*,err=901) config % iuma_corr
      if (config % iuma_corr == 1) then
         read(10,*,err=901) config % uma_phi,config % uma_dt 
      else
         config % uma_phi = 0.0 ; config % uma_dt = 0.0 
      endif

!  ** read SRC correction options
      read(10,*,err=901) config % i_src_corr
      if (config % i_src_corr == 1) then
         read(10,*,err=901) config % src_fast, config % src_tlag 
      else
         config % src_fast = 0.0 ; config % src_tlag = 0.0 
      endif

      
!  ** read ScS phase correction options
      read(10,*,err=901) config % iscs_corr

      if (config % iscs_corr == 1) then
         read(10,*,err=901) config % scs_slw
!  *** warn about ScS correction
         write(0,'(a)') '-------------------------------------'
         write(0,'(a)') ' WARNING! ScS option is a prototype'
         write(0,'(a)') '   and may well give poor results'
         write(0,'(a)') '------------------------------------'
      else
         config % scs_slw = 0.0
      endif

!  ** read ScS phase correction options
      read(10,*,err=901) config % i_rotate_to_ABC

      if (config % i_rotate_to_ABC == 1) then
         read(10,*,err=901) config % slw
      else
         config % slw = 0.0
      endif
         
      return           
!  ** error handling
900   print*,'<!> ERROR IN SHEBA: sheba.in not found'
      stop
901   print*,'<!> ERROR IN SHEBA: error reading sheba.in'
      stop           
      end subroutine read_config
!=======================================================================

!=======================================================================
      subroutine get_traces(h1,h2,v,iorder)
!=======================================================================
!  
!     Read the input traces and determine the h1,h2,v ordering
!
!-----------------------------------------------------------------------
      use f90sac  ! use the f90sac module
      use sheba_config ! use the sheba_config module
      use event_info ! use the event info module
!-----------------------------------------------------------------------
      implicit none
      type (SACTrace) :: h1,h2,v ! the re-ordered traces for analysis
      type (SACTrace) :: traces(3) ! the input traces
      character (len=80) :: fn ! filename
      integer :: iorder(3) ! index to re-order the traces
      integer :: i,ii
      
!  ** read the three files
      do i = 1,3            
         fn = trim(config % fname_base) // '.' // config % comp(i)
         call f90sac_readtrace(fn,traces(i))
      enddo ! do i = 1,3

!  ** check that cmpaz and cmpinc are set
      if ( traces(1)%cmpaz == SAC_rnull .or.  &
           traces(2)%cmpaz == SAC_rnull .or.  & 
           traces(3)%cmpaz == SAC_rnull) then
         print*,'<!> ERROR IN SHEBA: cmpaz header not set in one or more files'
      endif   
      if ( traces(1)%cmpinc == SAC_rnull .or.  &
           traces(2)%cmpinc == SAC_rnull .or.  & 
           traces(3)%cmpinc == SAC_rnull) then
         print*,'<!> ERROR IN SHEBA: cmpinc header not set in one or more files'
      endif   

!  ** determine ordering and check inclinations
      ii = 1
      do i = 1,3
!     ** check component inclinations are 0 or 90
         
         if ( abs(traces(i) % cmpinc) > angtol .and.  & 
             abs(traces(i) % cmpinc - 90.0) > angtol ) then
            print*,'<!> ERROR IN SHEBA: input trace is not ', & 
               'horizontal or vertical'
            stop
         endif
                
         if (abs(traces(i) % cmpinc) < angtol) then
            iorder(3) = i
         else 
            iorder(ii) = i
            ii = ii + 1
         endif     
      enddo ! do i = 1,3

!  ** make h1 the smallest azimuth
      if (traces(iorder(1)) % cmpaz > traces(iorder(2)) % cmpaz) then
         i=iorder(1)
         iorder(1) = iorder(2)
         iorder(2) = i
      endif   
      
!  ** assign the traces      
      h1 = traces(iorder(1))
      h2 = traces(iorder(2))
      v = traces(iorder(3))
      
!  ** get some useful event information from the vertical header      
      event % dist = v % dist
      event % az = v % az
      event % baz = v % baz
!  ** check that the horizontal traces are orthogonal
      if (f90sac_orth2d(h1,h2) == 0) then
         print*,'<!> ERROR IN SHEBA: input horizontals are ', & 
               'not orthogonal'
         STOP
      endif     
!  ** done!      
      return           
      end subroutine get_traces
!=======================================================================
