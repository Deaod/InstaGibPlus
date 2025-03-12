// ===============================================================
// Stats.ST_SniperRifle: put your comment here

// Created by UClasses - (C) 2000-2001 by meltdown@thirdtower.com
// ===============================================================

class ST_SniperRifle extends SniperRifle;

var IGPlus_WeaponImplementation WImp;

enum EZoomState {
	ZS_None,
	ZS_Zooming,
	ZS_Zoomed,
	ZS_Reset
};
var EZoomState ZoomState;

var WeaponSettingsRepl WSettings;

// Variables for client-side animations
var Rotator GV;           // For storing view rotation
var float yMod;           // For handedness calculations

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

	ForEach AllActors(Class'IGPlus_WeaponImplementation', WImp)
		break;		// Find master :D
}

// Initialize values for client-side visual calculations
simulated function yModInit()
{
	if (bbPlayer(Owner) != None && Owner.Role == ROLE_AutonomousProxy)
		GV = bbPlayer(Owner).ViewRotation;

	if (PlayerPawn(Owner) == None)
		return;

	yMod = PlayerPawn(Owner).Handedness;
	if (yMod != 2.0)
		yMod *= Default.FireOffset.Y;
	else
		yMod = 0;
}

// Client-side shell case spawning
simulated function DoClientShellCase(PlayerPawn Pwner, vector HitLoc, Vector X, Vector Y, Vector Z)
{
	local UT_ShellCase s;

	// Make sure we're on the client
	if (Level.NetMode == NM_Client || Level.NetMode == NM_Standalone) {
		s = Spawn(class'UT_ShellCase', Pwner,, HitLoc);
		if (s != None) 
		{
			s.DrawScale = 2.0;
			s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);
			s.RemoteRole = ROLE_None;
		}
	}
}

// Handle client-side firing
simulated function bool ClientFire(float Value)
{
	local bbPlayer bbP;
	
	if (Owner.IsA('Bot'))
		return Super.ClientFire(Value);
		
	bbP = bbPlayer(Owner);
	if (Role < ROLE_Authority && bbP != None)
	{
		if (bbP.ClientCannotShoot() || bbP.Weapon != Self) {
			return false;
		}
		
		if ((AmmoType == None) && (AmmoName != None))
		{
			// ammocheck
			GiveAmmo(Pawn(Owner));
		}
		
		if (AmmoType.AmmoAmount > 0)
		{
			Instigator = Pawn(Owner);
			GotoState('ClientFiring');
			bPointing = True;
			bCanClientFire = true;
			if (bRapidFire || (FiringSpeed > 0))
				Pawn(Owner).PlayRecoil(FiringSpeed);
			
			// ALWAYS play client effects in ClientFire for immediate feedback regardless of compensation setting
			if (GetWeaponSettings().SniperUseClientSideAnimations) {
				ClientPlayEffects();
			}
		}
	}
	
	return Super.ClientFire(Value);
}

// Play client-side effects only (no hit detection)
simulated function ClientPlayEffects()
{
	local vector X, Y, Z;
	local PlayerPawn P;

	P = PlayerPawn(Owner);
	if (P == None)
		return;
	
	// Initialize positions for visual effects
	yModInit();
	GetAxes(GV, X, Y, Z);
	
	// Spawn shell case for visual effect only (client-side)
	DoClientShellCase(P, Owner.Location + CalcDrawOffset() + 30 * X + (2.8 * yMod + 5.0) * Y - Z * 1, X, Y, Z);
	
	// Play firing animation
	PlayAnim(FireAnims[Rand(5)], GetWeaponSettings().SniperReloadAnimSpeed(), 0.05);
	
	// Add muzzle flash if not zoomed
	if (P.DesiredFOV == P.DefaultFOV)
		bMuzzleFlash++;
}

// Handle rendering overlays for client-side visuals
simulated function RenderOverlays(Canvas Canvas)
{
	Super.RenderOverlays(Canvas);
	yModInit();

	// Check if we need to fire
	if (Role < ROLE_Authority && bbPlayer(Owner) != None && bbPlayer(Owner).bFire != 0 && !IsInState('ClientFiring')) {
		ClientFire(1);
	}
}

function TraceFire(float Accuracy) {
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other;
	local Pawn PawnOwner;

	PawnOwner = Pawn(Owner);

	Owner.MakeNoise(PawnOwner.SoundDampening);
	GetAxes(PawnOwner.ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + PawnOwner.Eyeheight * vect(0,0,1); 
	AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2*AimError, False, False);	
	X = vector(AdjustedAim);
	EndTrace = StartTrace + 100000 * X;
	if (WImp.WeaponSettings.SniperUseReducedHitbox)
		Other = WImp.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace, PawnOwner);
	else
		Other = PawnOwner.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
}

function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_Shellcase s;
	local Pawn PawnOwner;
	local vector Momentum;

	PawnOwner = Pawn(Owner);
	
	// Only spawn shell case on server if compensation is disabled
	if (WImp.WSettingsRepl.SniperUseClientSideAnimations) {
		s = Spawn(class'ST_UT_ShellCaseOwnerHidden',Owner, '', Owner.Location + CalcDrawOffset() + 30 * X + (2.8 * FireOffset.Y+5.0) * Y - Z * 1);
		if (s != None) {
			s.DrawScale = 2.0;
			s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);
		}
	}
	else {
		s = Spawn(class'UT_ShellCase',, '', Owner.Location + CalcDrawOffset() + 30 * X + (2.8 * FireOffset.Y+5.0) * Y - Z * 1);
		if (s != None) {
			s.DrawScale = 2.0;
			s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);
		}
	}

	// Wall hit effects - always spawn on server for Level and Mover hits
	if (Other == Level) {
		Spawn(class'UT_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
	} else if ((Other != self) && (Other != Owner) && (Other != None)) {
		if (Other.IsA('Mover')) {
			Spawn(class'UT_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
		}

		// Headshot handling
		if (Other.bIsPawn && CheckHeadShot(Pawn(Other), HitLocation, X) &&
			(instigator.IsA('PlayerPawn') || (instigator.IsA('Bot') && !Bot(Instigator).bNovice))
		) {
			Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);
			Other.TakeDamage(
				WImp.WeaponSettings.SniperHeadshotDamage,
				PawnOwner,
				HitLocation,
				WImp.WeaponSettings.SniperHeadshotMomentum * 35000 * X,
				AltDamageType);
		} else {
			// Regular hit handling
			if (Other.bIsPawn) {
				Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);
				Momentum = WImp.WeaponSettings.SniperMomentum * 30000.0*X;
				
				// Always spawn hit effects on players on the server
				Spawn(class'UT_SpriteSmokePuff',,,HitLocation+HitNormal*9);
			} else {
				Momentum = 30000.0*X;
				if (Other.IsA('Carcass') == false)
					Spawn(class'UT_SpriteSmokePuff',,,HitLocation+HitNormal*9);
			}

			Other.TakeDamage(
				WImp.WeaponSettings.SniperDamage,
				PawnOwner,
				HitLocation,
				Momentum,
				MyDamageType);
		}
	}
}

function bool CheckHeadShot(Pawn P, vector HitLocation, vector BulletDir) {
    local UTPlusDummy Dummy;
    local bbPlayer bbP;
    local vector Loc;

    Loc = P.Location;
    if (WImp.WeaponSettings.bEnablePingCompensation) {
        bbP = bbPlayer(Owner);
        if (bbP != none)
            Dummy = bbP.zzUTPure.FindDummy(P);
        if (Dummy != none)
            Loc = Dummy.Location;
    }

    if (WImp.WeaponSettings.SniperUseReducedHitbox == false)
        return (HitLocation.Z - Loc.Z > 0.62 * P.CollisionHeight);

    return WImp.CheckHeadShot(P, HitLocation, BulletDir, Loc);
}

function SetSwitchPriority(pawn Other)
{	// Make sure "old" priorities are kept.
	local int i;
	local name temp, carried;

	if ( PlayerPawn(Other) != None )
	{
		for ( i=0; i<ArrayCount(PlayerPawn(Other).WeaponPriority); i++)
			if ( IsA(PlayerPawn(Other).WeaponPriority[i]) )		// <- The fix...
			{
				AutoSwitchPriority = i;
				return;
			}
		// else, register this weapon
		carried = 'SniperRifle';
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
	
	// Always play sound and animation
	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*3.0);
	PlayAnim(FireAnims[Rand(5)], GetWeaponSettings().SniperReloadAnimSpeed(), 0.05);

	// Handle muzzle flash
	if ((PlayerPawn(Owner) != None) && 
		(PlayerPawn(Owner).DesiredFOV == PlayerPawn(Owner).DefaultFOV)) {
		// If compensation is enabled, only show muzzle flash on client side
		// Otherwise use the old server-side logic
		if (!GetWeaponSettings().SniperUseClientSideAnimations || 
			(Level.NetMode == NM_Standalone) || 
			(PlayerPawn(Owner).RemoteRole != ROLE_AutonomousProxy)) {
			bMuzzleFlash++;
		}
	}
}

simulated function PlaySelect() {
	bForceFire = false;
	bForceAltFire = false;
	bCanClientFire = false;
	if ( !IsAnimating() || (AnimSequence != 'Select') )
		PlayAnim('Select',GetWeaponSettings().SniperSelectAnimSpeed(),0.0);
	Owner.PlaySound(SelectSound, SLOT_Misc, Pawn(Owner).SoundDampening);	
}

simulated function TweenDown() {
	local float TweenTime;

	TweenTime = 0.05;
	if (Owner != none && Owner.IsA('bbPlayer') && bbPlayer(Owner).IGPlus_UseFastWeaponSwitch)
		TweenTime = 0.00;

	if ( IsAnimating() && (AnimSequence != '') && (GetAnimGroup(AnimSequence) == 'Select') )
		TweenAnim( AnimSequence, AnimFrame * GetWeaponSettings().SniperDownTime );
	else
		PlayAnim('Down', GetWeaponSettings().SniperDownAnimSpeed(), TweenTime);

	if (Owner.IsA('PlayerPawn') && PlayerPawn(Owner).Player.IsA('ViewPort')) {
		ZoomState = ZS_None;
		PlayerPawn(Owner).EndZoom();
	}
}

simulated function bool ClientAltFire(float Value) {
	if (Owner.IsA('PlayerPawn') == false) {
		Pawn(Owner).bFire = 1;
		Pawn(Owner).bAltFire = 0;
		Global.Fire(0);
	} else {
		GotoState('Idle');
	}

	return true;
}

simulated function Tick(float DeltaTime) {
	local PlayerPawn P;

	P = PlayerPawn(Owner);
	if (P != none &&
		P.Weapon == self &&
		bCanClientFire
	) {
		switch (ZoomState) {
		case ZS_None:
			if (P.bAltFire != 0) {
				if (P.Player.IsA('ViewPort'))
					P.StartZoom();
				SetTimer(0.2, true);
				ZoomState = ZS_Zooming;
			}
			break;
		case ZS_Zooming:
			if (P.bAltFire == 0) {
				if (P.Player.IsA('ViewPort'))
					P.StopZoom();
				ZoomState = ZS_Zoomed;
			}
			break;
		case ZS_Zoomed:
			if (P.bAltFire != 0) {
				if (P.Player.IsA('ViewPort'))
					P.EndZoom();
				SetTimer(0.0, false);
				ZoomState = ZS_Reset;
			}
			break;
		case ZS_Reset:
			if (P.bAltFire == 0) {
				ZoomState = ZS_None;
			}
			break;
		}
	}
}

// Add state for client-side firing
state ClientFiring
{

	simulated function AnimEnd() {
		if ((Pawn(Owner) == None) || ((AmmoType != None) && (AmmoType.AmmoAmount <= 0))) {
			PlayIdleAnim();
			GotoState('');
		}
		else if (!bCanClientFire) {
			GotoState('');
		}
		else if (Pawn(Owner).bFire != 0) {
			Global.ClientFire(0);
		}
		else {
			PlayIdleAnim();
			GotoState('');
		}
	}
}

// Client-active state to handle client-side firing
state ClientActive
{
	// Check if client can fire
	simulated function bool ClientFire(float Value)
	{
		if (Owner.IsA('Bot'))
			return Super.ClientFire(Value);
		bForceFire = bbPlayer(Owner) == None || !bbPlayer(Owner).ClientCannotShoot();
		return bForceFire;
	}

	// Check if client can alt-fire (for zoom functionality)
	simulated function bool ClientAltFire(float Value)
	{
		if (Owner.IsA('Bot'))
			return Super.ClientAltFire(Value);
		bForceAltFire = bbPlayer(Owner) == None || !bbPlayer(Owner).ClientCannotShoot();
		return bForceAltFire;
	}

	// Handle animation end in client active state
	simulated function AnimEnd()
	{
		if (Owner == None) {
			Global.AnimEnd();
			GotoState('');
		}
		else if (Owner.IsA('TournamentPlayer')
			&& (TournamentPlayer(Owner).PendingWeapon != None || TournamentPlayer(Owner).ClientPending != None)) {
			GotoState('ClientDown');
		}
		else if (bWeaponUp) {
			if ((bForceFire || (PlayerPawn(Owner).bFire != 0)) && Global.ClientFire(1))
				return;
			else if ((bForceAltFire || (PlayerPawn(Owner).bAltFire != 0)) && Global.ClientAltFire(1))
				return;
			PlayIdleAnim();
			GotoState('');
		}
		else {
			PlayPostSelect();
			bWeaponUp = true;
		}
	}
}

defaultproperties {
}
