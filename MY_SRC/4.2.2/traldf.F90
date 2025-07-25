MODULE traldf
   !!======================================================================
   !!                       ***  MODULE  traldf  ***
   !! Ocean Active tracers : lateral diffusive trends
   !!=====================================================================
   !! History :  9.0  ! 2005-11  (G. Madec)  Original code
   !!  NEMO      3.0  ! 2008-01  (C. Ethe, G. Madec)  merge TRC-TRA
   !!            3.7  ! 2013-12  (G. Madec) remove the optional computation from T & S anomaly profiles and traldf_bilapg
   !!             -   ! 2013-12  (F. Lemarie, G. Madec)  triad operator (Griffies) + Method of Stabilizing Correction
   !!             -   ! 2014-01  (G. Madec, S. Masson)  restructuration/simplification of lateral diffusive operators
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   tra_ldf       : update the tracer trend with the lateral diffusion trend
   !!   tra_ldf_init  : initialization, namelist read, and parameters control
   !!----------------------------------------------------------------------
   USE oce            ! ocean dynamics and tracers
   USE dom_oce        ! ocean space and time domain
   USE phycst         ! physical constants
   USE ldftra         ! lateral diffusion: eddy diffusivity & EIV coeff.
   USE ldfslp         ! lateral diffusion: iso-neutral slope
   USE traldf_lap_blp ! lateral diffusion: laplacian iso-level            operator  (tra_ldf_lap/_blp   routines)
   USE traldf_iso     ! lateral diffusion: laplacian iso-neutral standard operator  (tra_ldf_iso        routine )
   USE traldf_triad   ! lateral diffusion: laplacian iso-neutral triad    operator  (tra_ldf_triad      routine )
   USE trd_oce        ! trends: ocean variables
   USE trdtra         ! ocean active tracers trends
   !
   USE prtctl         ! Print control
   USE in_out_manager ! I/O manager
   USE lib_mpp        ! distribued memory computing library
   USE lbclnk         ! ocean lateral boundary conditions (or mpp link)
   USE timing         ! Timing

   IMPLICIT NONE
   PRIVATE

   PUBLIC   tra_ldf        ! called by step.F90
   PUBLIC   tra_ldf_init   ! called by nemogcm.F90

   !!----------------------------------------------------------------------
   !! NEMO/OCE 4.0 , NEMO Consortium (2018)
   !! $Id: traldf.F90 14834 2021-05-11 09:24:44Z hadcv $
   !! Software governed by the CeCILL license (see ./LICENSE)
   !!----------------------------------------------------------------------
#  include "do_loop_substitute.h90"
CONTAINS

   SUBROUTINE tra_ldf( kt, Kbb, Kmm, pts, Krhs )
      !!----------------------------------------------------------------------
      !!                  ***  ROUTINE tra_ldf  ***
      !!
      !! ** Purpose :   compute the lateral ocean tracer physics.
      !!----------------------------------------------------------------------
      INTEGER,                                   INTENT(in   ) :: kt              ! ocean time-step index
      INTEGER,                                   INTENT(in   ) :: Kbb, Kmm, Krhs  ! ocean time level indices
      INTEGER  ::  ji, jj, jk   ! dummy loop indices
      REAL(dp), DIMENSION(jpi,jpj,jpk,jpts,jpt), INTENT(inout) :: pts             ! active tracers and RHS of tracer equation
      !!
      REAL(wp), ALLOCATABLE, DIMENSION(:,:,:) ::   ztrdt, ztrds
      !!----------------------------------------------------------------------
      !
      IF( ln_timing )   CALL timing_start('tra_ldf')
      !
      IF( l_trdtra )   THEN                    !* Save ta and sa trends
         ALLOCATE( ztrdt(jpi,jpj,jpk) , ztrds(jpi,jpj,jpk) )
         ztrdt(:,:,:) = pts(:,:,:,jp_tem,Krhs)
         ztrds(:,:,:) = pts(:,:,:,jp_sal,Krhs)
      ENDIF
      !
      SELECT CASE ( nldf_tra )                 !* compute lateral mixing trend and add it to the general trend
      CASE ( np_lap   )                                  ! laplacian: iso-level operator
         CALL tra_ldf_lap  ( kt, Kmm, nit000,'TRA', ahtu, ahtv, gtsu, gtsv, gtui, gtvi, pts(:,:,:,:,Kbb), pts(:,:,:,:,Krhs),                   jpts,  1 )
      CASE ( np_lap_i )                                  ! laplacian: standard iso-neutral operator (Madec)
         CALL tra_ldf_iso  ( kt, Kmm, nit000,'TRA', ahtu, ahtv, gtsu, gtsv, gtui, gtvi, pts(:,:,:,:,Kbb), pts(:,:,:,:,Kbb), pts(:,:,:,:,Krhs), jpts,  1 )
      CASE ( np_lap_it )                                 ! laplacian: triad iso-neutral operator (griffies)
         CALL tra_ldf_triad( kt, Kmm, nit000,'TRA', ahtu, ahtv, gtsu, gtsv, gtui, gtvi, pts(:,:,:,:,Kbb), pts(:,:,:,:,Kbb), pts(:,:,:,:,Krhs), jpts,  1 )
      CASE ( np_blp , np_blp_i , np_blp_it )             ! bilaplacian: iso-level & iso-neutral operators
         CALL tra_ldf_blp  ( kt, Kmm, nit000,'TRA', ahtu, ahtv, gtsu, gtsv, gtui, gtvi, pts(:,:,:,:,Kbb), pts(:,:,:,:,Krhs),             jpts, nldf_tra )
      END SELECT
      !
      IF( l_trdtra )   THEN                    !* save the horizontal diffusive trends for further diagnostics
         ztrdt(:,:,:) = pts(:,:,:,jp_tem,Krhs) - ztrdt(:,:,:)
         ztrds(:,:,:) = pts(:,:,:,jp_sal,Krhs) - ztrds(:,:,:)
         CALL trd_tra( kt, Kmm, Krhs, 'TRA', jp_tem, jptra_ldf, ztrdt )
         CALL trd_tra( kt, Kmm, Krhs, 'TRA', jp_sal, jptra_ldf, ztrds )
         DEALLOCATE( ztrdt, ztrds )
      ENDIF
      
      !DO_2D( nn_hls, nn_hls, nn_hls, nn_hls)
      !   IF( mjg0(jj) == 3605 ) THEN
      !      DO jk = 1, mbkt(ji,jj)
      !         pts(ji,jj,jk,jp_sal,Krhs) = MIN(35._wp, pts(ji,jj,jk,jp_sal,Krhs))
      !      END DO
      !   ENDIF
      !END_2D
      

      !                                        !* print mean trends (used for debugging)
      IF(sn_cfctl%l_prtctl)   CALL prt_ctl( tab3d_1=pts(:,:,:,jp_tem,Krhs), clinfo1=' ldf  - Ta: ', mask1=tmask, &
         &                                  tab3d_2=pts(:,:,:,jp_sal,Krhs), clinfo2=       ' Sa: ', mask2=tmask, clinfo3='tra' )
      !
      IF( ln_timing )   CALL timing_stop('tra_ldf')
      !
   END SUBROUTINE tra_ldf


   SUBROUTINE tra_ldf_init
      !!----------------------------------------------------------------------
      !!                  ***  ROUTINE tra_ldf_init  ***
      !!
      !! ** Purpose :   Choice of the operator for the lateral tracer diffusion
      !!
      !! ** Method  :   set nldf_tra from the namtra_ldf logicals
      !!----------------------------------------------------------------------
      INTEGER ::   ioptio, ierr   ! temporary integers
      !!----------------------------------------------------------------------
      !
      IF(lwp) THEN                     !==  Namelist print  ==!
         WRITE(numout,*)
         WRITE(numout,*) 'tra_ldf_init : lateral tracer diffusive operator'
         WRITE(numout,*) '~~~~~~~~~~~~'
         WRITE(numout,*) '   Namelist namtra_ldf: already read in ldftra module'
         WRITE(numout,*) '      see ldf_tra_init report for lateral mixing parameters'
         WRITE(numout,*)
         !
         SELECT CASE( nldf_tra )             ! print the choice of operator
         CASE( np_no_ldf )   ;   WRITE(numout,*) '   ==>>>   NO lateral diffusion'
         CASE( np_lap    )   ;   WRITE(numout,*) '   ==>>>   laplacian iso-level operator'
         CASE( np_lap_i  )   ;   WRITE(numout,*) '   ==>>>   Rotated laplacian operator (standard)'
         CASE( np_lap_it )   ;   WRITE(numout,*) '   ==>>>   Rotated laplacian operator (triad)'
         CASE( np_blp    )   ;   WRITE(numout,*) '   ==>>>   bilaplacian iso-level operator'
         CASE( np_blp_i  )   ;   WRITE(numout,*) '   ==>>>   Rotated bilaplacian operator (standard)'
         CASE( np_blp_it )   ;   WRITE(numout,*) '   ==>>>   Rotated bilaplacian operator (triad)'
         END SELECT
      ENDIF
      !
   END SUBROUTINE tra_ldf_init

   !!======================================================================
END MODULE traldf
