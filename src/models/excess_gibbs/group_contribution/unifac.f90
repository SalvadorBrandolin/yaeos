module yaeos__models_ge_group_contribution_unifac
   !! UNIFAC module
   use yaeos__constants, only: pr, R
   use yaeos__models_ge, only: GeModel
   implicit none

   type :: Groups
      !! Group derived type.
      !!
      !! This type represent a molecule and it's groups
      !!
      integer, allocatable :: groups_ids(:)
      !! Indexes (ids) of each group in the main group matrix
      integer, allocatable :: number_of_groups(:)
      !! Count of each group in the molecule
      real(pr) :: surface_area
      !! Molecule surface area \(q\)
      real(pr) :: volume
      !! Molecule volume \(r\)
   end type Groups

   type, extends(GeModel) :: UNIFAC
      !! UNIFAC model derived type
      !!
      !! This type holds the needed parameters for using a UNIFAC \(G^E\) model
      !! mainly group areas, volumes and what temperature dependence function
      !! \(\psi(T)\) to use.
      !! It also holds the individual molecules of a particular system and
      !! the set of all groups in the system as a "stew" of groups instead of
      !! being them included in particular molecules.
      integer :: ngroups
      !! Total number of individual groups
      real(pr) :: z = 10
      !! Model constant
      real(pr), allocatable :: group_area(:)
      !! Group areas \(Q_k\)
      real(pr), allocatable :: group_volume(:)
      !! Group volumes \(R_k\)
      real(pr), allocatable :: thetas_ij(:, :)
      !! Area fractions of groups j (row) on molecules i (column)
      real(pr), allocatable :: vij(:,:)
      !! Ocurrences of each group j on each molecule i
      real(pr), allocatable :: qij(:,:)
      !! Area of each group j on each molecule i
      class(PsiFunction), allocatable :: psi_function
      !! Temperature dependance function of the model
      type(Groups), allocatable :: molecules(:)
      !! Substances present in the system
      type(Groups) :: groups_stew
      !! All the groups present in the system
   contains
      procedure :: excess_gibbs
   end type UNIFAC

   type, abstract :: PsiFunction
   contains
      procedure(temperature_dependence), deferred :: psi
   end type PsiFunction

   type, extends(PsiFunction) :: UNIFACPsi
      !! Original UNIFAC \(psi\) function
      !! \[
      !!    \psi_{ij}(T) = \exp(-\frac{A_{ij}}{T})
      !! \]
      real(pr), allocatable :: Eij(:, :)
   contains
      procedure :: psi => UNIFAC_temperature_dependence
   end type UNIFACPsi

   abstract interface
      subroutine temperature_dependence(&
         self, systems_groups, T, psi, dpsidt, dpsidt2&
         )
         import pr, PsiFunction, Groups
         class(PsiFunction) :: self
         class(Groups) :: systems_groups
         real(pr), intent(in) :: T
         real(pr), optional, intent(out) :: psi(:, :)
         real(pr), optional, intent(out) :: dpsidt(:, :)
         real(pr), optional, intent(out) :: dpsidt2(:, :)
      end subroutine temperature_dependence
   end interface

contains

   subroutine excess_gibbs(self, n, t, Ge, GeT, GeT2, Gen, GeTn, Gen2)
      !! Excess Gibbs and derivs procedure
      use iso_fortran_env, only: error_unit
      class(UNIFAC), intent(in) :: self !! Model
      real(pr), intent(in) ::n(:) !! Moles vector
      real(pr), intent(in) :: t !! Temperature [K]
      real(pr), optional, intent(out) :: Ge !! Excess Gibbs
      real(pr), optional, intent(out) :: GeT !! \(\frac{dG^E}{dT}\)
      real(pr), optional, intent(out) :: GeT2 !! \(\frac{d^2G^E}{dT^2}\)
      real(pr), optional, intent(out) :: Gen(size(n))
      real(pr), optional, intent(out) :: GeTn(size(n))
      real(pr), optional, intent(out) :: Gen2(size(n), size(n))

      real(pr) :: x(size(n))
      real(pr) :: ln_gamma_c(size(n)), ln_gamma_r(size(n)), ln_activity(size(n))
      real(pr) :: nt, dxidni(size(n), size(n))
      real(pr) :: Ge_c, Ge_r
      real(pr) :: dGe_c_dn(size(n)), dGe_r_dn(size(n))

      integer :: i, j, nc

      write(error_unit, *) "WARN: UNIFAC not fully implemented yet"

      nt = sum(n)

      x = n/nt

      nc = size(self%molecules)

      ln_activity = 0

      !call combinatorial_activity(self, x, ln_gamma_c)
      !call residual_activity(self, x, T, ln_gamma_r)
      !ln_activity = ln_gamma_c + ln_gamma_r

      if (present(Ge)) then
         call Ge_combinatorial(self, n, Ge_c)
         call Ge_residual(self, n, T, Ge_r)
         Ge =  (Ge_c + Ge_r) * (R*T)
      end if

      if (present(GeN)) then 
         call Ge_combinatorial(self, n, Ge_c, dGe_c_dn)
         call Ge_residual(self, n, T, Ge_r, dGe_r_dn)
         Gen = dGe_c_dn + dGe_r_dn
      end if
   end subroutine excess_gibbs

   subroutine Ge_combinatorial(self, n, Ge, dGe_dn, dGe_dn2)
      class(UNIFAC) :: self

      real(pr), intent(in) :: n(:)
      real(pr), optional, intent(out) :: Ge
      real(pr), optional, intent(out) :: dGe_dn(:)
      real(pr), optional, intent(out) :: dGe_dn2(:,:)

      ! Flory-Huggins variables
      real(pr) :: Ge_fh
      real(pr) :: dGe_fh_dn(size(n))
      real(pr) :: dGe_fh_dn2(size(n),size(n))

      ! Staverman-Guggenheim variables
      real(pr) :: Ge_sg
      real(pr) :: dGe_sg_dn(size(n))
      real(pr) :: dGe_sg_dn2(size(n),size(n))

      ! utility
      real(pr) :: nq, nr, n_t
      integer :: i, j

      associate(&
         q => self%molecules%surface_area,&
         r => self%molecules%volume,&
         z => self%z &
         )

         nr = dot_product(n, r)
         nq = dot_product(n, q)
         n_t = sum(n)

         if (present(Ge)) then
            Ge_fh = dot_product(n, log(r)) - n_t * log(nr) + n_t * log(n_t)
            Ge_sg = z/2 * sum(n * q * (log(q/r) - log(nq) + log(nr)))
         end if

         if (present(dGe_dn)) then
            dGe_fh_dn = log(r) - log(nr) + log(n_t) + 1 - n_t * r / nr
            dGe_sg_dn = z/2*q*(-log((r*nq)/(q*nr)) - 1 + (r*nq)/(q*nr))
         end if

         if (present(dGe_dn2)) then
            dGe_fh_dn2 = 0.0_pr
            dGe_sg_dn2 = 0.0_pr
            do concurrent(i=1:size(n), j=1:size(n))
               dGe_fh_dn2(i,j) = -(r(i) + r(j))/nr + 1/n_t + n_t*r(i)*r(j)/ nr**2
               dGe_sg_dn2(i,j) = z/2*(-q(i)*q(j)/nq + (q(i)*r(j) + q(j)*r(i))/nr - r(i)*r(j)*nq/nr**2)
            end do
         end if
      end associate

      if (present(Ge)) Ge = Ge_fh + Ge_sg
      if (present(dGe_dn)) dGe_dn = dGe_fh_dn + dGe_sg_dn
      if (present(dGe_dn2)) dGe_dn2 = dGe_fh_dn2 + dGe_sg_dn2
   end subroutine Ge_combinatorial

   subroutine Ge_residual(self, n, T, Ge, dGe_dn, dGe_dn2, dGe_dT, dGe_dT2, dGe_dTn)
      class(UNIFAC) :: self

      real(pr), intent(in) :: n(:)
      real(pr), intent(in) :: T
      real(pr), optional, intent(out) :: Ge
      real(pr), optional, intent(out) :: dGe_dn(:)
      real(pr), optional, intent(out) :: dGe_dn2(:,:)
      real(pr), optional, intent(out) :: dGe_dT
      real(pr), optional, intent(out) :: dGe_dT2
      real(pr), optional, intent(out) :: dGe_dTn(:,:)

      ! Thetas variables
      real(pr) :: theta_j(self%ngroups), total_groups_area

      ! Ejk variables
      real(pr) :: Ejk(self%ngroups,self%ngroups)
      real(pr) :: dEjk_dt(self%ngroups, self%ngroups)
      real(pr) :: dEjk_dt2(self%ngroups, self%ngroups)

      ! Lambdas variables
      real(pr) :: lambda_k(self%ngroups)
      real(pr) :: dlambda_k_dT(self%ngroups)
      real(pr) :: dlambda_k_dT2(self%ngroups)
      real(pr) :: dlambda_k_dn(size(self%molecules), self%ngroups)
      real(pr) :: dlambda_k_dn2(self%ngroups, size(self%molecules), size(self%molecules))

      real(pr) :: lambda_ik(size(self%molecules), self%ngroups)
      real(pr) :: dlambda_ik_dT(size(self%molecules), self%ngroups)
      real(pr) :: dlambda_ik_dT2(size(self%molecules), self%ngroups)

      ! Indexes used for groups
      integer :: j, k

      ! Indexes used for components
      integer :: i, l

      ! Auxiliars
      real(pr) :: sum_vijQjEjk(size(self%molecules), self%ngroups)
      real(pr) :: sum_nivijQjEjk(self%ngroups)
      real(pr) :: sum_vikQk(size(self%molecules))
      real(pr) :: sum_vQLambda(size(self%molecules))
      real(pr) :: tempsum(size(self%molecules))
      real(pr) :: sum_nlvlj(self%ngroups)
      real(pr) :: sum_nivikQk

      call thetas(self, n, theta_j, total_groups_area)
      call self%psi_function%psi(self%groups_stew, T, Ejk, dEjk_dt, dEjk_dt2)

      ! ========================================================================
      ! Auxiliars
      ! ------------------------------------------------------------------------
      do i=1,size(self%molecules)
         sum_vikQk(i) = sum(self%vij(i,:) * self%qij(i,:))
      end do
      sum_nivikQk = sum(n * sum_vikQk)

      do j=1,self%ngroups
         sum_nlvlj(j) = sum(n * self%vij(:,j))
      end do

      ! ========================================================================
      ! Lambda_k
      ! ------------------------------------------------------------------------
      if (present(Ge) .or. present(dGe_dn)) then
         do k=1,self%ngroups
            lambda_k(k) = log(sum(theta_j * Ejk(:,k)))
         end do
      end if

      if (present(dGe_dn) .or. present(dGe_dTn) .or. present(dGe_dn2)) then
         do i=1,size(self%molecules)
            do k=1,self%ngroups
               sum_vijQjEjk(i,k) = sum(self%vij(i,:) * self%qij(i,:) * Ejk(:,k))
            end do
         end do

         do k=1,self%ngroups
            sum_nivijQjEjk(k) = sum(n * sum_vijQjEjk(:,k))
         end do

         do i=1,size(self%molecules)
            dlambda_k_dn(i,:) = sum_vijQjEjk(i,:) / sum_nivijQjEjk - sum_vikQk(i) / sum_nivikQk
         end do
      end if

      ! ========================================================================
      ! Lambda_ik
      ! ------------------------------------------------------------------------
      do k=1,self%ngroups
         do i=1,size(self%molecules)
            lambda_ik(i, k) = sum(self%thetas_ij(i, :) * Ejk(:, k))
         end do
      end do
      lambda_ik = log(lambda_ik)

      ! ========================================================================
      ! Ge
      ! ------------------------------------------------------------------------
      do i=1,size(self%molecules)
         sum_vQLambda(i) = sum(self%vij(i,:) * self%qij(i,:) * (lambda_k - lambda_ik(i,:)))
      end do
      
      if (present(Ge)) then
         Ge = - sum(n * sum_vQLambda)
      end if

      ! ========================================================================
      ! dGe_dn
      ! ------------------------------------------------------------------------
      if (present(dGe_dn)) then
         do i=1,size(self%molecules)
            tempsum(i) = sum(self%vij(i,:) * self%qij(i,:) * dlambda_k_dn(i,:))
         end do
         dGe_dn = -sum_vQLambda - sum(n * tempsum)
      end if
   end subroutine Ge_residual

   subroutine residual_activity(&
      self, n, T, ln_gamma_r, dln_gamma_r_dn, dln_gamma_r_dt, dln_gamma_r_dtn&
      )
      class(UNIFAC) :: self

      real(pr), intent(in) :: n(:)
      real(pr), intent(in) :: T
      real(pr), intent(out) :: ln_gamma_r(:)
      real(pr), optional, intent(out) :: dln_gamma_r_dn(:, :)
      real(pr), optional, intent(out) :: dln_gamma_r_dT(:)
      real(pr), optional, intent(out) :: dln_gamma_r_dTn(:, :)

      real(pr) :: lambda_k(self%ngroups), lambda_ki(self%ngroups, size(n))
      real(pr) :: psi_jk(self%ngroups, self%ngroups)

      real(pr) :: lambda_sum, lambda_theta_psi_sum, q_k, thetas_j(self%ngroups)

      ! Indexes used for groups
      integer :: j, k

      ! Indexes used for components
      integer :: i, l, alpha

      integer :: gi, v_k_alpha

      call groups_lambda(self, n, T, lambda_k=lambda_k, lambda_ki=lambda_ki, psi_jk=psi_jk)
      call thetas(self, n, thetas_j)

      do alpha=1,size(n)
         lambda_sum = 0.0_pr
         lambda_theta_psi_sum = 0.0_pr

         do k=1,size(self%molecules(alpha)%number_of_groups)
            gi = self%molecules(alpha)%groups_ids(k)
            v_k_alpha = self%molecules(alpha)%number_of_groups(k)

            j = findloc(self%groups_stew%groups_ids, gi, dim=1)
            q_k = self%group_area(j)

            lambda_sum = &
               lambda_sum &
               + v_k_alpha * q_k * (lambda_k(k) - lambda_ki(k, alpha))

            lambda_theta_psi_sum = lambda_theta_psi_sum + &
               v_k_alpha * q_k * (&
               thetas_j(k) * psi_jk(k, j) / dot_product(thetas_j, psi_jk(:, k)) - 1)
         end do

         ln_gamma_r(alpha) = - lambda_sum - lambda_theta_psi_sum
      end do

      ! ln_G = 0
      ! ln_G_i = 0
      ! ln_gamma_r = 0

      ! if (present(dln_gamma_dn)) dln_gamma_dn = 0
      ! nc = size(self%molecules)

      ! call group_big_gamma(self, x, T, ln_G, dln_gammadx=dln_Gdn)

      ! do i=1,nc
      !    xpure = 0
      !    xpure(i) = 1
      !    call group_big_gamma(&
      !       self, xpure, T, ln_G_i(i, :), dln_Gammadx=dln_G_idn(i, :, :) &
      !       )
      ! end do

      ! do i=1,nc
      !    do k=1,size(self%molecules(i)%groups_ids)
      !       ! Get the index of the group k of molecule i in the whole stew of
      !       ! groups.
      !       ! TODO: These kind of `findloc` maybe can be optimized.
      !       gi = findloc(&
      !          self%groups_stew%groups_ids - self%molecules(i)%groups_ids(k), &
      !          0, dim=1 &
      !          )

      !       ln_gamma_r(i) = ln_gamma_r(i) &
      !          + self%molecules(i)%number_of_groups(k) &
      !          * (ln_G(gi) - ln_G_i(i, gi))

      !       if (present(dln_gamma_dn)) then
      !          ! Compositional derivative
      !          do j=1,i
      !             dln_gamma_dn(i, j) = dln_gamma_dn(i, j) &
      !                + self%molecules(i)%number_of_groups(k) &
      !                * (dln_Gdn(gi, j) - dln_G_idn(i, gi, j))
      !             dln_gamma_dn(j, i) = dln_gamma_dn(i, j)
      !          end do
      !       end if
      !    end do
      ! end do
   end subroutine residual_activity

   subroutine combinatorial_activity(self, n, ln_gamma_c, dln_gamma_c_dn)
      class(UNIFAC) :: self
      real(pr), intent(in) :: n(:)
      real(pr), intent(out) :: ln_gamma_c(:)
      real(pr), optional, intent(out) :: dln_gamma_c_dn(:, :)

      real(pr) :: ln_gamma_c_fh(size(n)), ln_gamma_c_sg(size(n))
      real(pr) :: dln_gamma_c_fh_dn(size(n), size(n))
      real(pr) :: dln_gamma_c_sg_dn(size(n), size(n))
      real(pr) :: nq, nr, n_t
      integer :: i, j

      associate (&
         q => self%molecules%surface_area,&
         r => self%molecules%volume,&
         z => self%z &
         )
         nq = dot_product(n, q)
         nr = dot_product(n, r)

         n_t = sum(n)

         ln_gamma_c_fh = log(r) - log(nr) + log(n_t) + 1 - n_t * r / nr
         ln_gamma_c_sg = z/2*q*(-log((r*nq)/(q*nr)) - 1 + (r*nq)/(q*nr))

         ln_gamma_c = ln_gamma_c_fh + ln_gamma_c_sg

         if (present(dln_gamma_c_dn)) then
            dln_gamma_c_dn = 0.0_pr
            do concurrent(i=1:size(n), j=1:size(n))
               dln_gamma_c_fh_dn(i,j) = &
                  -(r(i) + r(j))/nr + 1/n_t + n_t*r(i)*r(j)/ nr**2

               dln_gamma_c_sg_dn(i,j) = &
                  z/2*(-q(i)*q(j)/nq + (q(i)*r(j) + q(j)*r(i))/nr - r(i)*r(j)*nq/nr**2)

               dln_gamma_c_dn(i,j) = dln_gamma_c_fh_dn(i,j) + dln_gamma_c_sg_dn(i,j)
            end do
         end if
      end associate
   end subroutine combinatorial_activity

   subroutine ln_activity_coefficient(&
      self, n, T, lngamma, &
      dln_gammadt, dln_gammadt2, dln_gammadn, dln_gammadtn, dln_gammadn2 &
      )
      class(UNIFAC), intent(in) :: self
      real(pr), intent(in) :: n(:)
      real(pr), intent(in) :: T
      real(pr), intent(out) :: lngamma(:)
      real(pr), optional, intent(out) :: dln_gammadt(:)
      real(pr), optional, intent(out) :: dln_gammadt2(:)
      real(pr), optional, intent(out) :: dln_gammadn(:, :)
      real(pr), optional, intent(out) :: dln_gammadtn(:, :)
      real(pr), optional, intent(out) :: dln_gammadn2(:, :, :)

      real(pr) :: ln_gamma_c(size(n))
      real(pr) :: dln_gamma_c_dt(size(n))
      real(pr) :: dln_gamma_c_dt2(size(n))
      real(pr) :: dln_gamma_c_dn (size(n), size(n))
      real(pr) :: dln_gamma_c_dtn(size(n), size(n))
      real(pr) :: dln_gamma_c_dn2(size(n), size(n), size(n))

      real(pr) :: ln_gamma_r(size(n))
      real(pr) :: dln_gamma_r_dt(size(n))
      real(pr) :: dln_gamma_r_dt2(size(n))
      real(pr) :: dln_gamma_r_dn (size(n), size(n))
      real(pr) :: dln_gamma_r_dtn(size(n), size(n))
      real(pr) :: dln_gamma_r_dn2(size(n), size(n), size(n))

      call combinatorial_activity(self, n, ln_gamma_c)
      call residual_activity(self, n, T, ln_gamma_r)

      lngamma = ln_gamma_c + ln_gamma_r
   end subroutine ln_activity_coefficient

   subroutine UNIFAC_temperature_dependence(self, systems_groups, T, psi, dpsidt, dpsidt2)
      class(UNIFACPsi) :: self !! \(\psi\) function
      class(Groups) :: systems_groups !! Groups in the system
      real(pr), intent(in) :: T !! Temperature
      real(pr), optional, intent(out) :: psi(:, :) !! \(\psi\)
      real(pr), optional, intent(out) :: dpsidt(:, :)
      real(pr), optional, intent(out) :: dpsidt2(:, :)

      integer :: i, j
      integer :: ig, jg
      integer :: ngroups

      ngroups = size(systems_groups%groups_ids)

      do concurrent(i=1:ngroups, j=1:ngroups)
         ig = systems_groups%groups_ids(i)
         jg = systems_groups%groups_ids(j)
         if (present(psi)) &
            psi(i, j) = exp(-self%Eij(ig, jg) / T)
         if (present(dpsidt)) &
            dpsidt(i, j) = self%Eij(ig, jg) * psi(i, j) / T**2
         if (present(dpsidt2)) &
            dpsidt2(i, j) = &
            self%Eij(ig, jg) * (self%Eij(ig, jg) - 2*T) * psi(i, j) / T**4
      end do

   end subroutine UNIFAC_temperature_dependence

   subroutine thetas(self, n, theta_j, total_groups_area)
      type(UNIFAC) :: self
      real(pr), intent(in) :: n(:)

      real(pr), intent(out) :: theta_j(:)
      !! Group j total area fraction
      real(pr), optional, intent(out) :: total_groups_area
      !! Total groups area

      integer :: j, l, m !! A fines practicos i y l son lo mismo aca.
      integer :: gi !! group m id

      real(pr) :: ga(size(theta_j)) !! Area of group j in the system
      real(pr) :: qjl_contribution, total_area

      associate(&
         group_area => self%group_area, &
         stew => self%groups_stew, &
         molecs => self%molecules &
         )

         ! Calculate Total area fraction of group j
         theta_j = 0.0_pr
         ga = 0.0_pr

         do l=1,size(molecs)
            do m=1,size(molecs(l)%number_of_groups)
               gi = molecs(l)%groups_ids(m)

               ! Locate group m in the stew ordering (position j of group m).
               j = findloc(stew%groups_ids, gi, dim=1)

               ! Contribution of the molecule l to the group j area.
               qjl_contribution = (&
                  n(l) * group_area(gi) * molecs(l)%number_of_groups(m) &
                  )

               ! Add the contribution to the contributions storing vector.
               ga(j) = ga(j) + qjl_contribution

               ! Adding to the total groups area.
               total_area = total_area + qjl_contribution
            end do
         end do

         theta_j = ga / total_area

         ! Return total_groups_area if asked (needed on lambda derivatives)
         if (present(total_groups_area)) total_groups_area = total_area
      end associate
   end subroutine thetas

   subroutine group_area_fraction(&
      self, x, &
      theta, dthetadx, dthetadx2 &
      )
      type(UNIFAC) :: self
      real(pr), intent(in) :: x(:)


      real(pr), intent(out) :: theta(:) !! Group area fraction
      real(pr), optional, intent(out) :: dthetadx(:, :)
      real(pr), optional, intent(out) :: dthetadx2(:, :, :)

      real(pr) :: gf(size(theta)) !! Group fraction
      real(pr) :: dgfdx(size(theta), size(x))
      real(pr) :: dgfdx2(size(theta), size(x), size(x))

      real(pr) :: ga(size(theta)) !! Area of group j in the system
      real(pr) :: dgadx(size(theta), size(x))

      real(pr) :: total_groups_area, dtga_dx(size(x))
      integer :: i, l, j, m, gi

      associate(&
         group_area => self%group_area, stew => self%groups_stew, &
         molecs => self%molecules &
         )

         theta = 0
         dgadx = 0

         total_groups_area = 0
         dtga_dx = 0
         ga = 0

         do l=1,size(molecs)
            do m=1,size(molecs(l)%number_of_groups)
               gi = molecs(l)%groups_ids(m)
               j = findloc(stew%groups_ids, gi, dim=1)

               ga(j) = ga(j) + x(l) * group_area(gi) * molecs(l)%number_of_groups(m)

               if (present(dthetadx)) then
                  dgadx(j, l) = group_area(gi) * molecs(l)%number_of_groups(m)
                  dtga_dx(l) = dtga_dx(l) + molecs(l)%number_of_groups(m) * group_area(gi)
               end if

               total_groups_area = total_groups_area &
                  + x(l) * molecs(l)%number_of_groups(m) * group_area(gi)
            end do
         end do

         theta = ga/total_groups_area
         if (present(dthetadx)) then
            do i=1,size(x)
               dthetadx(:, i) = &
                  dgadx(:, i)/total_groups_area &
                  - ga(:)/total_groups_area**2 * dtga_dx(i)

               if (present(dthetadx2)) then
                  do j=i,size(x)
                     dthetadx2(:, i, j) = &
                        dtga_dx(i) * dtga_dx(j) * ga(:)/total_groups_area**3 &
                        - ( dgadx(:, i) * dgadx(:, j)**2 )/total_groups_area**2
                  end do
               end if
            end do
         end if
      end associate
   end subroutine group_area_fraction

   subroutine groups_lambda(&
      self, n, T, &
      lambda_k, dlambda_k_dT, dlambda_k_dT2, &
      lambda_ki, dlambda_ki_dT, dlambda_ki_dT2, &
      dlambda_k_dn, dlambda_k_dn2, psi_jk)
      class(UNIFAC) :: self

      real(pr), intent(in) :: n(:)
      real(pr), intent(in) :: T
      real(pr), optional, intent(out) :: lambda_k(:)
      real(pr), optional, intent(out) :: dlambda_k_dT(:)
      real(pr), optional, intent(out) :: dlambda_k_dT2(:)
      real(pr), optional, intent(out) :: dlambda_k_dn(:, :)
      real(pr), optional, intent(out) :: dlambda_k_dn2(:, :, :)
      real(pr), optional, intent(out) :: lambda_ki(:, :)
      real(pr), optional, intent(out) :: dlambda_ki_dT(:)
      real(pr), optional, intent(out) :: dlambda_ki_dT2(:)
      real(pr), optional, intent(out) :: psi_jk(:, :)

      ! psi
      real(pr) :: psi(self%ngroups,self%ngroups)
      real(pr) :: dpsidt(self%ngroups, self%ngroups)
      real(pr) :: dpsidt2(self%ngroups,self%ngroups)

      ! Total thetas
      real(pr) :: theta_j(self%ngroups), total_groups_area
      real(pr) :: thtea_dot_psi(self%ngroups)

      ! Indexes used for groups
      integer :: j, k

      ! Indexes used for components
      integer :: i

      ! Output asked
      logical :: dx, dx2, dt, dt2

      dt = .false.
      dt2 = .false.

      ! ========================================================================
      ! Temperature dependance
      ! ------------------------------------------------------------------------
      if (dt2) then
         dlambda_k_dT = 0
         dlambda_k_dT2 = 0
         dlambda_ki_dT = 0
         dlambda_ki_dT2 = 0
         call self%psi_function%psi(self%groups_stew, T, psi, dpsidt, dpsidt2)
      else if(dt) then
         dlambda_k_dT = 0
         dlambda_ki_dT = 0
         call self%psi_function%psi(self%groups_stew, T, psi, dpsidt)
      else
         call self%psi_function%psi(self%groups_stew, T, psi)
      end if

      if (present(psi_jk)) psi_jk = psi

      ! ========================================================================
      ! Lambda_k
      ! ------------------------------------------------------------------------
      if (present(lambda_k)) then
         call thetas(self, n, theta_j, total_groups_area)

         do k=1,self%ngroups
            lambda_k(k) = log(dot_product(theta_j, psi(:, k)))
         end do
      end if

      ! ========================================================================
      ! Lambda_ki
      ! ------------------------------------------------------------------------
      if (present(lambda_ki)) then
         do k=1,self%ngroups
            do i=1,size(self%molecules)
               lambda_ki(k, i) = dot_product(self%thetas_ij(:, i), psi(:, k))
            end do
         end do

         lambda_ki = log(lambda_ki)
      end if
   end subroutine groups_lambda

   subroutine group_big_gamma(&
      self, x, T, ln_Gamma, dln_Gammadx, dln_Gammadt, dln_Gammadt2, dln_Gammadx2&
      )
      class(UNIFAC) :: self
      real(pr), intent(in) :: x(:) !< Molar fractions
      real(pr), intent(in) :: T !! Temperature
      real(pr), intent(out) :: ln_Gamma(:) !! \(\ln \Gamma_i\)
      real(pr), optional, intent(out) :: dln_Gammadt(:) !! \(\ln \Gamma_i\)
      real(pr), optional, intent(out) :: dln_Gammadt2(:) !! \(\ln \Gamma_i\)
      real(pr), optional, intent(out) :: dln_Gammadx(:, :) !!
      real(pr), optional, intent(out) :: dln_Gammadx2(:, :, :) !!

      real(pr) :: theta(self%ngroups)
      !! Group area fractions
      real(pr) :: dthetadx(self%ngroups, size(x))
      !! First derivative of group area fractions with composition
      real(pr) :: dthetadx2(self%ngroups, size(x), size(x))
      !! Second derivative of group area fractions with composition
      real(pr) :: psi(self%ngroups,self%ngroups)
      !! \(\psi(T)\) parameter
      real(pr) :: dpsidt(self%ngroups, self%ngroups)
      real(pr) :: dpsidt2(self%ngroups,self%ngroups)

      ! Number of groups and components
      integer :: ng, nc

      ! Indexes used for groups
      integer :: n, m, k, gi

      ! Indexes for components
      integer :: i, j

      logical :: dx, dx2, dt, dt2

      ! Auxiliar variables to ease calculations
      real(pr) :: updown, updowndt, updowndx(size(x))
      real(pr) :: down(size(theta)), downdt(size(theta)), &
         downdt2(size(theta)), downdx(size(theta), size(x))

      ng = self%ngroups
      nc = size(x)
      dt = present(dln_Gammadt)
      dt2 = present(dln_Gammadt2)
      dx = present(dln_Gammadx)
      dx2 = present(dln_gammadx2)

      ! Initializate as zero
      ln_gamma = 0

      ! ========================================================================
      ! Calculate only the needed derivatives of the area fractions
      ! ------------------------------------------------------------------------
      if (dx2) then
         dln_Gammadx = 0
         dln_Gammadx2 = 0
         call group_area_fraction(&
            self, x, theta=theta, dthetadx=dthetadx, dthetadx2=dthetadx2 &
            )
      else if (dx) then
         dln_Gammadx = 0
         call group_area_fraction(self, x, theta=theta, dthetadx=dthetadx)
      else
         call group_area_fraction(self, x, theta=theta)
      end if

      ! ========================================================================
      ! Temperature dependance
      ! ------------------------------------------------------------------------
      if (dt2) then
         dln_Gammadt = 0
         dln_Gammadt2 = 0
         call self%psi_function%psi(self%groups_stew, T, psi, dpsidt, dpsidt2)
      else if(dt) then
         dln_Gammadt = 0
         call self%psi_function%psi(self%groups_stew, T, psi, dpsidt)
      else
         call self%psi_function%psi(self%groups_stew, T, psi)
      end if
      ! ========================================================================
      ! This parameters are used to avoid repeated calculations
      ! ------------------------------------------------------------------------
      down = 0
      downdx = 0
      do concurrent(m=1:ng, n=1:ng)
         down(m) = down(m) + theta(n) * psi(n, m)
         if (dt)  downdt(m) = downdt(m) + theta(n) * dpsidt(n, m)
         if (dt2) downdt2(m) = downdt(m) + theta(n) * dpsidt2(n, m)
         if(dx)   downdx(m, :) = downdx(m, :) + dthetadx(n, :) * psi(n, m)
      end do

      do k=1,ng
         if (theta(k) == 0) cycle

         ! Get the group index on the main matrix
         gi = self%groups_stew%groups_ids(k)
         updown = sum(theta(:) * psi(k, :)/down(:))

         ln_Gamma(k) = self%group_area(gi) * (&
            1 - log(sum(theta(:) * psi(:, k))) - updown &
            )

         if (dt) then
            temp_deriv: block
               real(pr) :: F(ng), Z(ng)
               do i=1,ng
                  F(i) = sum(theta(:) * dpsidt(:, i))
                  Z(i) = 1/sum(theta(:) * psi(:, i))
               end do

               dln_Gammadt(k) = self%group_area(gi) * (&
                  sum(&
                  Z(:) * (&
                  theta(:) * dpsidt(:, k) &
                  + theta(:) * psi(:, k) * F(:)* Z(:) &
                  ))  - F(k) * Z(k) &
                  )
            end block temp_deriv
         end if

         if (dx) then
            do concurrent(i=1:nc)
               dln_Gammadx(k, i) = self%group_area(gi) * ( &
                  - sum(dthetadx(:, i) * psi(:, k))/sum(theta(:) * psi(:, k)) &
                  - sum(dthetadx(:, i) * psi(k, :) / down(:))                 &
                  + sum(downdx(:, i) * theta(:) * psi(k, :) / down(:)**2)     &
                  )
            end do
            if (dx2) then
               do concurrent(j=1:nc)
               end do
            end if
         end if
      end do
   end subroutine group_big_gamma

   function thetas_i(nm, ng, group_area, stew, molecules) result(thetas_ij)
      integer, intent(in) :: nm !! Number of molecules
      integer, intent(in) :: ng !! Number of groups
      real(pr), intent(in) :: group_area(:) !! Group k areas
      type(Groups), intent(in) :: stew !! All the groups present in the system
      type(Groups), intent(in) :: molecules(:) !! Molecules
      real(pr) :: thetas_ij(nm, ng) !! Group j area fraction on molecule i

      real(pr) :: total_area_i(nm)
      real(pr) :: qki_contribution

      integer :: gi !! group k id
      integer :: i, j, k

      thetas_ij = 0.0_pr
      total_area_i = 0.0_pr

      ! Obtain the total area of each molecule
      do i=1,size(molecules)
         do k=1,size(molecules(i)%number_of_groups)
            gi = molecules(i)%groups_ids(k)

            ! Locate group k in the stew ordering (position j of group k).
            j = findloc(stew%groups_ids, gi, dim=1)

            ! Contribution of the group k to the molecule i area.
            qki_contribution = (&
               group_area(gi) * molecules(i)%number_of_groups(k) &
               )

            ! Adding to the total area of each molecule
            total_area_i(i) = total_area_i(i) + qki_contribution
         end do
      end do

      ! Calculate the fraction of each group on each molecule
      thetas_ij = 0.0_pr

      do i=1,size(molecules)
         do k=1,size(molecules(i)%number_of_groups)
            gi = molecules(i)%groups_ids(k)

            j = findloc(stew%groups_ids, gi, dim=1)

            thetas_ij(i, j) = group_area(gi) * molecules(i)%number_of_groups(k) / total_area_i(i)
         end do
      end do
   end function thetas_i

   type(UNIFAC) function setup_unifac(molecules, Eij, Qk, Rk)
      !! UNIFAC model initialization.
      type(Groups), intent(in) :: molecules(:) !! Molecules
      real(pr), intent(in) :: Eij(:, :) !! Interaction Matrix
      real(pr), intent(in) :: Qk(:) !! Group k areas
      real(pr), intent(in) :: Rk(:) !! Group k volumes

      type(Groups) :: soup
      type(UNIFACPsi) :: psi_function

      integer, allocatable :: vij(:, :)
      real(pr), allocatable :: qij(:,:)

      integer :: gi, i, j, k

      setup_unifac%molecules = molecules

      allocate(soup%groups_ids(0))
      allocate(soup%number_of_groups(0))

      ! ========================================================================
      ! Count all the individual groups and each molecule volume and area
      ! ------------------------------------------------------------------------
      associate(&
         r => setup_unifac%molecules%volume, &
         q => setup_unifac%molecules%surface_area &
         )
         ! Get all the groups indexes and counts into a single stew of groups.
         do i=1,size(molecules)
            r(i) = 0
            q(i) = 0

            do j=1,size(molecules(i)%groups_ids)
               gi = molecules(i)%groups_ids(j)

               ! Calculate molecule i volume and area
               r(i) = r(i) + molecules(i)%number_of_groups(j) * Rk(gi)
               q(i) = q(i) + molecules(i)%number_of_groups(j) * Qk(gi)

               if (all(soup%groups_ids - gi  /= 0)) then
                  ! Add group if it wasn't included yet
                  soup%groups_ids = [soup%groups_ids, gi]
                  soup%number_of_groups = [soup%number_of_groups, 0]
               end if

               ! Find where is the group located in the main soup of
               ! groups.
               gi = findloc(soup%groups_ids - gi, 0, dim=1)

               soup%number_of_groups(gi) = soup%number_of_groups(gi) &
                  + molecules(i)%number_of_groups(j)
            end do
         end do
      end associate
      ! ========================================================================
      ! Build a matrixes vij and Qij
      ! ------------------------------------------------------------------------
      allocate(vij(size(molecules), size(soup%number_of_groups)))
      allocate(qij(size(molecules), size(soup%number_of_groups)))

      vij = 0
      qij = 0.0_pr
      do i=1,size(molecules)
         do k=1,size(molecules(i)%number_of_groups)
            gi = molecules(i)%groups_ids(k)

            ! Index of group for Area
            j = findloc(soup%groups_ids, gi, dim=1)

            vij(i,j) = molecules(i)%number_of_groups(k)
            qij(i,j) = Qk(gi)
         end do
      end do
      ! ========================================================================

      psi_function%Eij = Eij
      setup_unifac%groups_stew = soup
      setup_unifac%ngroups = size(soup%number_of_groups)
      setup_unifac%psi_function = psi_function
      setup_unifac%group_area = Qk
      setup_unifac%group_volume = Rk
      setup_unifac%thetas_ij = thetas_i(&
         size(molecules), size(soup%number_of_groups), Qk, soup, molecules)
      setup_unifac%vij = vij
      setup_unifac%qij = qij
   end function setup_unifac
end module yaeos__models_ge_group_contribution_unifac
