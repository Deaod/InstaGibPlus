// ===============================================================
// Stats.ST_enforcer: put your comment here

// Created by UClasses - (C) 2000-2001 by meltdown@thirdtower.com
// ===============================================================

class ST_enforcer extends enforcer;

var IGPlus_WeaponImplementation WImp;
var WeaponSettingsRepl WSettings;
var vector CDO;       // Client draw offset
var float yMod;       // Handedness modifier
var float LastFiredTime;
var bool bInitAnim;   // Flag to track first animation in AltFiring

simulated final function WeaponSettingsRepl FindWeaponSettings() {
	local WeaponSettingsRepl S;

	foreach AllActors(class'WeaponSettingsRepl', S)
		return S;

	return none;
}

simulated final function WeaponSettingsRepl GetWeaponSettings() {
	if (WSettings != none)
		return WSettings;

	WSettings = FindWeaponSettings();
	return WSettings;
}

function PostBeginPlay()
{
	Super.PostBeginPlay();

	ForEach AllActors(class'IGPlus_WeaponImplementation', WImp)
		break;		// Find master :D
}

// Initialize client-side variables
simulated function InitClientVars() {
	if (PlayerPawn(Owner) == None)
		return;

	yMod = PlayerPawn(Owner).Handedness;
	if (yMod != 2.0)
		yMod *= Default.FireOffset.Y;
	else
		yMod = 0;

	// For SlaveEnforcer, we need to negate the Y offset
	if (bIsSlave && yMod != 0)
		yMod = -yMod;

	CDO = CalcDrawOffsetClient();

	if (!bIsSlave && SlaveEnforcer != None && ST_enforcer(SlaveEnforcer) != None) {
		ST_enforcer(SlaveEnforcer).InitClientVars();
	}
}

simulated function bool ClientFire(float Value) {
	local Pawn PawnOwner;
	local bool Result;
	local bool bIsClient;

	PawnOwner = Pawn(Owner);
	if (PawnOwner == None)
		return false;

	bIsClient = (Role < ROLE_Authority);

	// Do client-side animations if we're on the client AND compensation is enabled
	if (bIsClient && GetWeaponSettings().EnforcerUseClientSideAnimations) {
		if (Level.TimeSeconds - LastFiredTime < 0.2)
			return false;

		if ((AmmoType == None) && (AmmoName != None)) {
			GiveAmmo(PawnOwner);
		}
		
		if (AmmoType.AmmoAmount > 0) {
			Instigator = PawnOwner;
			GotoState('ClientFiring');
			bPointing = True;
			bCanClientFire = true;
			if (bRapidFire || (FiringSpeed > 0))
				PawnOwner.PlayRecoil(FiringSpeed);
				
			InitClientVars();
			PlayFiring();
			
			// Only spawn shell case on client for visual feedback
			SpawnShellCaseClient();
			
			LastFiredTime = Level.TimeSeconds;
			return true;
		}
		return false;
	}
	
	// If we're on the server OR compensation is disabled, use standard behavior
	Result = Super.ClientFire(Value);
	return Result;
}

simulated function bool ClientAltFire(float Value) {
	local Pawn PawnOwner;
	local bool Result;
	local bool bIsClient;

	PawnOwner = Pawn(Owner);
	if (PawnOwner == None)
		return false;

	bIsClient = (Role < ROLE_Authority);

	// Do client-side animations if we're on the client AND compensation is enabled
	if (bIsClient && GetWeaponSettings().EnforcerUseClientSideAnimations) {
		if ((AmmoType == None) && (AmmoName != None)) {
			GiveAmmo(PawnOwner);
		}
		
		if (AmmoType.AmmoAmount > 0) {
			AltAccuracy = 0.4;
			Instigator = PawnOwner;
			GotoState('ClientAltFiring');
			bPointing = True;
			bCanClientFire = true;
			if (bRapidFire || (FiringSpeed > 0))
				PawnOwner.PlayRecoil(FiringSpeed);
				
			InitClientVars();
			PlayAltFiring();
			
			// No need to spawn shell case here, this will be handled in state ClientAltFiring
			return true;
		}
		return false;
	}
	
	// If we're on the server OR compensation is disabled, use standard behavior
	Result = Super.ClientAltFire(Value);
	return Result;
}

// Client-side shell case spawning
simulated function SpawnShellCaseClient() {
	local UT_Shellcase s;
	local vector realLoc;
	local vector X, Y, Z;
	local Pawn PawnOwner;
	local bool bMainEnforcer;

	PawnOwner = Pawn(Owner);
	if (PawnOwner == None)
		return;
		
	// Determine if this is the main enforcer or slave
	bMainEnforcer = !bIsSlave;
	
	GetAxes(PawnOwner.ViewRotation, X, Y, Z);
	realLoc = Owner.Location + CDO;
	
	s = Spawn(class'UT_ShellCase', Owner, '', realLoc + 20 * X + yMod * Y + Z);
	if (s != None) {
		s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);
	}	

}

function TraceFire(float Accuracy) {
	local vector RealOffset;
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local Actor Other;
	local Pawn PawnOwner;

	RealOffset = FireOffset;
	FireOffset *= 0.35;
	if ( (SlaveEnforcer != None) || bIsSlave )
		Accuracy = FClamp(3*Accuracy,0.75,3);
	else if ( Owner.IsA('Bot') && !Bot(Owner).bNovice )
		Accuracy = FMax(Accuracy, 0.45);

	PawnOwner = Pawn(Owner);

	Owner.MakeNoise(PawnOwner.SoundDampening);
	GetAxes(PawnOwner.ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
	AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2*AimError, False, False);	
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000;
	X = vector(AdjustedAim);
	EndTrace += (10000 * X);
	if (WImp.WeaponSettings.EnforcerUseReducedHitbox)
		Other = WImp.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace, PawnOwner);
	else
		Other = PawnOwner.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace);
	
	// Always use ProcessTraceHit with flag for shell case handling
	ProcessTraceHit(Other, HitLocation, HitNormal, X, Y, Z);

	FireOffset = RealOffset;

	// Higor: move slave enforcer to TraceFire start location
	// to ensure firing sounds are played from the right place
	if (Owner != None && (Level.NetMode == NM_DedicatedServer || Level.NetMode == NM_ListenServer)) {
		if (bIsSlave && !bCollideActors)
			SetLocation(Owner.Location + CalcDrawOffset());
		else if (SlaveEnforcer != None && !SlaveEnforcer.bCollideActors)
			SlaveEnforcer.SetLocation(Owner.Location + SlaveEnforcer.CalcDrawOffset());
	}
}

// Simplified ProcessTraceHit that handles both compensation and standard modes
function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_Shellcase s;
	local vector realLoc;
	local Pawn PawnOwner;
	local vector Momentum;
	local float Damage;
	local PlayerPawn PlayerOwner;
	local bool bUseClientSideAnimations;

	PawnOwner = Pawn(Owner);
	PlayerOwner = PlayerPawn(Owner);
	
	// Check if we're using client-side animations
	bUseClientSideAnimations = (PlayerOwner != None && WImp.WSettingsRepl.EnforcerUseClientSideAnimations);

	// Spawn shell case on server, hidden from owner if client-side animations are used
	realLoc = Owner.Location + CalcDrawOffset();
	if (bUseClientSideAnimations) {
		// Use the special shell case class that's designed to hide from owner
		s = Spawn(class'ST_UT_ShellCaseOwnerHidden', PlayerOwner, '', realLoc + 20 * X + FireOffset.Y * Y + Z);
		if (s != None) {
			s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);
		}
	} else {
		s = Spawn(class'UT_ShellCase',, '', realLoc + 20 * X + FireOffset.Y * Y + Z);
		if (s != None)
			s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);
	}
	
	// Wall hit effects
	if (Other == Level) {
		if (bIsSlave || (SlaveEnforcer != None)) {
			Spawn(class'UT_LightWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
		} else {
			Spawn(class'UT_WallHit',,, HitLocation+HitNormal, Rotator(HitNormal));
		}
	}
	else if ((Other != self) && (Other != Owner) && (Other != None)) {
		if (FRand() < 0.2)
			X *= 5;

		Momentum = 3000.0 * X;
		if (Other.bIsPawn) {
			if (SlaveEnforcer == none && bIsSlave == false)
				Momentum *= WImp.WeaponSettings.EnforcerMomentum;
			else
				Momentum *= WImp.WeaponSettings.EnforcerMomentumDouble;
		}

		if (SlaveEnforcer == none && bIsSlave == false)
			Damage = WImp.WeaponSettings.EnforcerDamage;
		else
			Damage = WImp.WeaponSettings.EnforcerDamageDouble;

		Other.TakeDamage(
			Damage,
			PawnOwner,
			HitLocation,
			Momentum,
			MyDamageType
		);
		
		if (!Other.bIsPawn && !Other.IsA('Carcass')) {
			Spawn(class'UT_SpriteSmokePuff',,, HitLocation+HitNormal*9);
		} else {
			Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);
		}
	}
}

state ClientFiring {
	simulated function BeginState() {
		Super(TournamentWeapon).BeginState();
		if (SlaveEnforcer != None)
			SetTimer(GetWeaponSettings().EnforcerShotOffsetDouble, false);
		else 
			SetTimer(0.5, false);
	}
	
	simulated function bool ClientFire(float Value) {
		return false;
	}

	simulated function bool ClientAltFire(float Value) {
		return false;
	}
}

state ClientAltFiring {
	simulated function BeginState() {
		Super(TournamentWeapon).BeginState();
		if (SlaveEnforcer != None)
			SetTimer(GetWeaponSettings().EnforcerShotOffsetDouble, false);
		else 
			SetTimer(0.5, false);
		
	}

	simulated function bool ClientFire(float Value)
	{
		if ( bIsSlave )
			Global.ClientFire(Value);
		return false;
	}

	simulated function Timer()
	{
		if ( (SlaveEnforcer != none) && SlaveEnforcer.ClientAltFire(0) )
			return;
		SetTimer(0.5, false);
	}

	simulated function AnimEnd()
	{
		if ( Pawn(Owner) == None )
			GotoState('');
		else if ( Ammotype.AmmoAmount <= 0 )
		{
			PlayAnim('T2', 0.9, 0.05);	
			GotoState('');
		}
		else if ( !bIsSlave && !bCanClientFire )
			GotoState('');
		else if ( bFirstFire || (Pawn(Owner).bAltFire != 0) )
		{
			if ( AnimSequence == 'T2' )
				PlayAltFiring();
			else
			{
				PlayRepeatFiring();
				if (GetWeaponSettings().EnforcerUseClientSideAnimations) 
					SpawnShellCaseClient();
				bFirstFire = false;
			}
		}
		else if ( Pawn(Owner).bFire != 0 )
		{
			if ( HasAnim('T2') && (AnimSequence != 'T2') )
				PlayAnim('T2', 0.9, 0.05);	
			else
				Global.ClientFire(0);
		}
		else
		{
			if ( HasAnim('T2') && (AnimSequence != 'T2') )
				PlayAnim('T2', 0.9, 0.05);	
			else
				GotoState('');
		}
	}

	simulated function EndState()
	{
		Super.EndState();
		if ( SlaveEnforcer != None )
			SlaveEnforcer.GotoState('');
	}
}

state NormalFire {
ignores Fire, AltFire, AnimEnd;

Begin:
	FlashCount++;
	if (SlaveEnforcer != none)
		SetTimer(GetWeaponSettings().EnforcerShotOffsetDouble, false);
	FinishAnim();
	if (bIsSlave)
		GotoState('Idle');
	else 
		Finish();
}

state AltFiring {
ignores Fire, AltFire, AnimEnd;

Begin:
	if (SlaveEnforcer != none)
		SetTimer(GetWeaponSettings().EnforcerShotOffsetDouble, false);
	FinishAnim();
Repeater:	
	if (AmmoType.UseAmmo(1)) {
		FlashCount++;
		if (SlaveEnforcer != None)
			Pawn(Owner).PlayRecoil(3 * FiringSpeed);
		else if (!bIsSlave)
			Pawn(Owner).PlayRecoil(1.5 * FiringSpeed);
		TraceFire(AltAccuracy);
		PlayRepeatFiring();
		FinishAnim();
	}

	if (AltAccuracy < 3)
		AltAccuracy += 0.5;
	if (bIsSlave) {
		if ((Pawn(Owner).bAltFire!=0) && AmmoType.AmmoAmount>0)
			Goto('Repeater');
	}
	else if (bChangeWeapon)
		GotoState('DownWeapon');
	else if ((Pawn(Owner).bAltFire!=0) && AmmoType.AmmoAmount>0) {
		if (PlayerPawn(Owner) == None)
			Pawn(Owner).bAltFire = int(FRand() < AltReFireRate);
		Goto('Repeater');
	}
	PlayAnim('T2', 0.9, 0.05);
	FinishAnim();
	Finish();
}

// Compatibility between client and server logic
simulated function vector CalcDrawOffsetClient() {
	local vector DrawOffset;
	local Pawn PawnOwner;
	local vector WeaponBob;
	
	PawnOwner = Pawn(Owner);
	if (PawnOwner == None)
		return vect(0,0,0);

	DrawOffset = CalcDrawOffset();
	
	// On client, make adjustments to match server
	if (Level.NetMode == NM_Client) {
		// Correct for EyeHeight differences
		DrawOffset -= (PawnOwner.EyeHeight * vect(0,0,1));
		DrawOffset += (PawnOwner.BaseEyeHeight * vect(0,0,1));
	
		// Remove WeaponBob, not applied on server
		WeaponBob = BobDamping * PawnOwner.WalkBob;
		WeaponBob.Z = (0.45 + 0.55 * BobDamping) * PawnOwner.WalkBob.Z;
		DrawOffset -= WeaponBob;
	}
	
	return DrawOffset;
}

function bool HandlePickupQuery( inventory Item )
{
	if (GetWeaponSettings().EnforcerAllowDouble) {
		return super.HandlePickupQuery(Item);
	} else {
		return super(TournamentWeapon).HandlePickupQuery(Item);
	}
}

function SetSwitchPriority(pawn Other)
{	// Make sure "old" priorities are kept.
	local int i;
	local name temp, carried;

	if ( PlayerPawn(Other) != None )
	{
		// also set double switch priority

		for ( i=0; i<ArrayCount(PlayerPawn(Other).WeaponPriority); i++)
			if ( PlayerPawn(Other).WeaponPriority[i] == 'doubleenforcer' )
			{
				DoubleSwitchPriority = i;
				break;
			}

		for ( i=0; i<ArrayCount(PlayerPawn(Other).WeaponPriority); i++)
			if ( IsA(PlayerPawn(Other).WeaponPriority[i]) )		// <- The fix...
			{
				AutoSwitchPriority = i;
				return;
			}
		// else, register this weapon
		carried = 'enforcer';
		for ( i=AutoSwitchPriority; i<ArrayCount(PlayerPawn(Other).WeaponPriority); i++ )
		{
			if ( PlayerPawn(Other).WeaponPriority[i] == '' )
			{
				PlayerPawn(Other).WeaponPriority[i] = carried;
				return;
			}
			else if ( i<ArrayCount(PlayerPawn(Other).WeaponPriority)-1 )
			{
				temp = PlayerPawn(Other).WeaponPriority[i];
				PlayerPawn(Other).WeaponPriority[i] = carried;
				carried = temp;
			}
		}
	}
}

simulated function PlayFiring() {
	local float AnimSpeed;
	if (SlaveEnforcer == none && bIsSlave == false)
		AnimSpeed = GetWeaponSettings().EnforcerReloadAnimSpeed();
	else
		AnimSpeed = GetWeaponSettings().EnforcerReloadDoubleAnimSpeed();

	PlayOwnedSound(FireSound, SLOT_None,2.0*Pawn(Owner).SoundDampening);
	bMuzzleFlash++;
	PlayAnim('Shoot', AnimSpeed * (0.5 + 0.31 * FireAdjust), 0.02);
}

simulated function PlayAltFiring() {
	local float AnimSpeed;
	if (SlaveEnforcer == none && bIsSlave == false)
		AnimSpeed = GetWeaponSettings().EnforcerReloadAltAnimSpeed();
	else
		AnimSpeed = GetWeaponSettings().EnforcerReloadAltDoubleAnimSpeed();

	PlayAnim('T1', AnimSpeed * 1.3, 0.05);
	bFirstFire = true;
}

simulated function PlayRepeatFiring() {
	local float AnimSpeed;
	if (SlaveEnforcer == none && bIsSlave == false)
		AnimSpeed = GetWeaponSettings().EnforcerReloadRepeatAnimSpeed();
	else
		AnimSpeed = GetWeaponSettings().EnforcerReloadRepeatDoubleAnimSpeed();

	if ((PlayerPawn(Owner) != None)
		&& ((Level.NetMode == NM_Standalone) || PlayerPawn(Owner).Player.IsA('ViewPort')))
	{
		if (InstFlash != 0.0)
			PlayerPawn(Owner).ClientInstantFlash( -0.2, vect(325, 225, 95));
		PlayerPawn(Owner).ShakeView(ShakeTime, ShakeMag, ShakeVert);
	}
	if ( Affector != None )
		Affector.FireEffect();
	bMuzzleFlash++;
	PlayOwnedSound(FireSound, SLOT_None,2.0*Pawn(Owner).SoundDampening);
	PlayAnim('Shot2', AnimSpeed * (0.7 + 0.3 * FireAdjust), 0.05);
}

simulated function PlaySelect() {
	bForceFire = false;
	bForceAltFire = false;
	bCanClientFire = false;
	if (!IsAnimating() || (AnimSequence != 'Select'))
		PlayAnim('Select', GetWeaponSettings().EnforcerSelectAnimSpeed(), 0.0);
	Owner.PlaySound(SelectSound, SLOT_Misc, Pawn(Owner).SoundDampening);	
}

simulated function TweenDown() {
	local float TweenTime;

	TweenTime = 0.05;
	if (Owner != none && Owner.IsA('bbPlayer') && bbPlayer(Owner).IGPlus_UseFastWeaponSwitch)
		TweenTime = 0.00;

	if (IsAnimating() && (AnimSequence != '') && (GetAnimGroup(AnimSequence) == 'Select'))
		TweenAnim( AnimSequence, AnimFrame * GetWeaponSettings().EnforcerDownTime );
	else
		PlayAnim('Down', GetWeaponSettings().EnforcerDownAnimSpeed(), TweenTime);
}

defaultproperties {
}