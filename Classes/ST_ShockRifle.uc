// ===============================================================
// Stats.ST_ShockRifle: ShockRifle with ping compensation
// ===============================================================

class ST_ShockRifle extends ShockRifle;

var IGPlus_WeaponImplementation WImp;
var WeaponSettingsRepl WSettings;

var ST_ShockProj LocalDummy;
var vector CDO;       // Client draw offset
var float LastFiredTime;
var float yMod;       // Handedness modifier

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

	ForEach AllActors(Class'IGPlus_WeaponImplementation', WImp) {
		break;
	}
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

	CDO = CalcDrawOffsetClient();
}

simulated function bool ClientFire(float Value) {
	local Pawn PawnOwner;
	local bool Result;
	local bool bIsClient;

	PawnOwner = Pawn(Owner);
	if (PawnOwner == None) 
		return false;

	bIsClient = (Role < ROLE_Authority);

	// Do client-side effects if we're on the client AND compensation is enabled
	if (bIsClient && GetWeaponSettings().ShockBeamUseClientSideAnimations) {
		if (Level.TimeSeconds - LastFiredTime < 0.4) 
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
			if (PlayerPawn(Owner) != None)
				PlayerPawn(Owner).ClientInstantFlash(-0.4, vect(450, 190, 650));
				
			// Perform client-side trace and spawn effects
			TraceFire_Client();
			LastFiredTime = Level.TimeSeconds;
			return true;
		}
		return false;
	}
	
	// If we're on the server OR compensation is disabled, use standard behavior
	Result = Super.ClientFire(Value);
	return Result;
}

// Client-side shock beam tracing and effect spawning
simulated function TraceFire_Client() {
    local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
    local actor Other;
    local Pawn PawnOwner;
    local vector SmokeLocation;
    
    PawnOwner = Pawn(Owner);
    if (PawnOwner == None)
        return;
    
    GetAxes(PawnOwner.ViewRotation, X, Y, Z);
    
    StartTrace = Owner.Location + CDO + yMod * Y + FireOffset.Z * Z;
    EndTrace = StartTrace + (10000 * vector(PawnOwner.ViewRotation));
    
    SmokeLocation = Owner.Location + CDO + (FireOffset.X + 20) * X + yMod * Y + FireOffset.Z * Z;
    
    // IMPROVED: Add an initial trace against world geometry to ensure we hit walls correctly
    if (Trace(HitLocation, HitNormal, EndTrace, StartTrace, true) != None) {
        // Hit world geometry (wall, floor, etc.)
        Other = Level; // Set to Level to indicate world hit
        
        // Update EndTrace to the hit location for the more detailed trace below
        EndTrace = HitLocation;
    }
    
    // Only perform actor trace if we didn't hit world geometry
    if (Other == None) {
        // Use the exact same method as server for actor traces
        if (WImp.WSettingsRepl.ShockBeamUseReducedHitbox) {
            Other = WImp.TraceShotClient(HitLocation, HitNormal, EndTrace, StartTrace, PawnOwner);
        } else {
            Other = bbPlayer(PawnOwner).TraceShotClient(HitLocation, HitNormal, EndTrace, StartTrace);
        }
    }
    
    // Safety checks
    if (Other == PawnOwner) {
        Other = None;
        HitLocation = EndTrace;
    }
    
    if (Other == None) {
        HitNormal = -X;
        HitLocation = EndTrace;
    }
    
    // Spawn client-side beam effect to the correct hit point
    ClientSpawnEffect(HitLocation, SmokeLocation, HitNormal);
}

// Spawn client-side beam effect
simulated function ClientSpawnEffect(vector HitLocation, vector SmokeLocation, vector HitNormal) {
	local ShockBeam Smoke;
	local Vector DVector;
	local int NumPoints;
	local rotator SmokeRotation;
	
	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector)/135.0;
	if (NumPoints < 1) {
		return;
	}
		
	SmokeRotation = rotator(DVector);
	SmokeRotation.roll = Rand(65535);
	
	Smoke = Spawn(class'ShockBeam', Owner,, SmokeLocation, SmokeRotation);
	if (Smoke != None) {
		Smoke.RemoteRole = ROLE_None; // Not replicated to server
		Smoke.bOwnerNoSee = false; // Maybe not needed?
		
		Smoke.MoveAmount = DVector/NumPoints;
		Smoke.NumPuffs = NumPoints - 1;
	}
}

function TraceFire(float Accuracy) {
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other;
	local Pawn PawnOwner;

	PawnOwner = Pawn(Owner);

	Owner.MakeNoise(PawnOwner.SoundDampening);
	GetAxes(PawnOwner.ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z; 
	EndTrace = StartTrace + (Accuracy * (FRand() - 0.5 )* Y * 1000) + (Accuracy * (FRand() - 0.5 ) * Z * 1000);

	if (bBotSpecialMove && (Tracked != None) && (
			((Owner.Acceleration == vect(0,0,0)) && (VSize(Owner.Velocity) < 40)) ||
			(Normal(Owner.Velocity) Dot Normal(Tracked.Velocity) > 0.95)
		)
	) {
		EndTrace += 10000 * Normal(Tracked.Location - StartTrace);
	} else {
		AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2.75*AimError, False, False);	
		EndTrace += (10000 * vector(AdjustedAim)); 
	}

	Tracked = None;
	bBotSpecialMove = false;

	if (WImp.WeaponSettings.ShockBeamUseReducedHitbox)
		Other = WImp.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace, PawnOwner);
	else
		Other = PawnOwner.TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
		
	ProcessTraceHit(Other, HitLocation, HitNormal, vector(AdjustedAim), Y, Z);
}

// Original function signature for compatibility
function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local PlayerPawn PlayerOwner;
	local Pawn PawnOwner;

	PawnOwner = Pawn(Owner);

	if (Other==None)
	{
		HitNormal = -X;
		HitLocation = Owner.Location + X*10000.0;
	}

	PlayerOwner = PlayerPawn(Owner);
	if (PlayerOwner != None)
		PlayerOwner.ClientInstantFlash(-0.4, vect(450, 190, 650));
		
	// Normal beam case - visible to all
	SpawnEffect(HitLocation, Owner.Location + CalcDrawOffset() + (FireOffset.X + 20) * X + FireOffset.Y * Y + FireOffset.Z * Z);
	
	if (ST_ShockProj(Other)!=None)
	{ 
		AmmoType.UseAmmo(2);
		ST_ShockProj(Other).SuperExplosion();
		return;
	}
	else
		Spawn(class'ut_RingExplosion5',,, HitLocation+HitNormal*8,rotator(HitNormal));

	if ((Other != self) && (Other != Owner) && (Other != None)) 
	{
		Other.TakeDamage(
			WImp.WeaponSettings.ShockBeamDamage,
			PawnOwner,
			HitLocation,
			WImp.WeaponSettings.ShockBeamMomentum*60000.0*X,
			MyDamageType);
	}
}

// Server-side beam spawning
function SpawnEffect(vector HitLocation, vector SmokeLocation)
{
	local ShockBeam Smoke;
	local Vector DVector;
	local int NumPoints;
	local rotator SmokeRotation;
	local PlayerPawn PlayerOwner;

	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector)/135.0;
	if (NumPoints < 1) {
		return;
	}
		
	SmokeRotation = rotator(DVector);
	SmokeRotation.roll = Rand(65535);
	
	PlayerOwner = PlayerPawn(Owner);
	
	// If compensation is active and this is the owner's client, use the hidden beam
	if (WImp.WSettingsRepl.ShockBeamUseClientSideAnimations && PlayerOwner != None && PlayerOwner == Owner) {
		// Use a beam that's hidden from the owner (will only be seen by other players)
		Smoke = Spawn(class'ST_ShockBeamOwnerHidden', Owner,, SmokeLocation, SmokeRotation);
	} else {
		// Standard beam visible to everyone
		Smoke = Spawn(class'ShockBeam',, , SmokeLocation, SmokeRotation);
	}
		
	Smoke.MoveAmount = DVector/NumPoints;
	Smoke.NumPuffs = NumPoints - 1;
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
		carried = 'ShockRifle';
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

simulated function PlaySelect() {
	bForceFire = false;
	bForceAltFire = false;
	bCanClientFire = false;
	if ( !IsAnimating() || (AnimSequence != 'Select') )
		PlayAnim('Select',GetWeaponSettings().ShockSelectAnimSpeed(),0.0);
	Owner.PlaySound(SelectSound, SLOT_Misc, Pawn(Owner).SoundDampening);	
}

simulated function TweenDown() {
	local float TweenTime;

	TweenTime = 0.05;
	if (Owner != none && Owner.IsA('bbPlayer') && bbPlayer(Owner).IGPlus_UseFastWeaponSwitch)
		TweenTime = 0.00;

	if ( IsAnimating() && (AnimSequence != '') && (GetAnimGroup(AnimSequence) == 'Select') )
		TweenAnim( AnimSequence, AnimFrame * GetWeaponSettings().ShockDownTime );
	else
		PlayAnim('Down', GetWeaponSettings().ShockDownAnimSpeed(), TweenTime);
}

state ClientFiring {
	simulated function bool ClientFire(float Value) {
		return false;
	}

	simulated function bool ClientAltFire(float Value) {
		return false;
	}
}

state ClientAltFiring {
	simulated function BeginState() {
		local Pawn PawnOwner;
		local vector X, Y, Z;
		local vector Start;
		local float Hand;

		if (GetWeaponSettings().ShockProjectileCompensatePing == false)
			return;

		PawnOwner = Pawn(Owner);

		if (Owner.IsA('PlayerPawn'))
			Hand = FClamp(PlayerPawn(Owner).Handedness, -1.0, 1.0);
		else
			Hand = 1.0;

		GetAxes(PawnOwner.ViewRotation,X,Y,Z);
		if (bHideWeapon)
			Start = Owner.Location + CalcDrawOffsetClient() + FireOffset.X * X + FireOffset.Z * Z;
		else
			Start = Owner.Location + CalcDrawOffsetClient() + FireOffset.X * X + FireOffset.Y * Hand * Y + FireOffset.Z * Z;
		LocalDummy = ST_ShockProj(Spawn(AltProjectileClass,,, Start,PawnOwner.ViewRotation));
		LocalDummy.RemoteRole = ROLE_None;
		LocalDummy.LifeSpan = PawnOwner.PlayerReplicationInfo.Ping * 0.00125;
		LocalDummy.bCollideWorld = false;
		LocalDummy.SetCollision(false, false, false);
	}
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

defaultproperties {
	AltProjectileClass=Class'ST_ShockProj'
}
