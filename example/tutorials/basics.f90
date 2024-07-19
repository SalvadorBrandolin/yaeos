program basics
   use yaeos ! First the module is imported (used). This will bring all the
             ! types and functions defined in the module to this program.
   implicit none
   ! ===========================================================================
   
   ! In yaeos, all residual Helmholtz models are based on the structure
   !  `ArModel` and are derivatives from it.
   ! Defining the model variable as an allocatable ArModel means that this
   ! variable can be redefined as any other kind of variable that derives from
   ! `ArModel`, for example `CubicEoS`.
   class(ArModel), allocatable :: model

   integer, parameter :: nc=2 !! In this case we define a constant number of
                              !! components.

   ! Used input variables
   real(pr) :: n(nc), Tc(nc), Pc(nc), w(nc)

   ! Output variables
   real(pr) :: P, dPdV
   ! ---------------------------------------------------------------------------

   ! Here the executed code starts

   ! A classic Cubic model can be defined with each component critial constants
   tc = [190._pr,  310._pr]
   pc = [14._pr,   30._pr ]
   w  = [0.001_pr, 0.03_pr]

   ! Here we chose to model with the PengRobinson EoS
   model = PengRobinson78(tc, pc, w)

   ! Number of moles vector
   n = [0.3, 0.7]

   ! Pressure calculation
   call model%pressure(n, V=2.5_pr, T=150._pr, P=P)
   print *, "P: ", P

   ! Derivatives can also be calculated when included as optional arguments!
   call model%pressure(n, V=2.5_pr, T=150._pr, P=P, dPdV=dPdV)
   print *, "dPdV: ", dPdV
end program basics