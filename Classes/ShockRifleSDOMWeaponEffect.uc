class ShockRifleSDOMWeaponEffect extends WeaponEffect
	abstract;

static function Play(
	PlayerPawn Player,
	ClientSettings Settings,
	PlayerReplicationInfo SourcePRI,
	vector SourceLocation,
	vector SourceOffset,
	Actor Target,
	vector TargetLocation,
	vector TargetOffset,
	vector HitNormal
) {
	local vector SmokeLocation;
	local vector HitLocation;

	if (Player.Level.NetMode == NM_DedicatedServer) return;

	SmokeLocation = SourceLocation;
	HitLocation = TargetLocation;

	PlayBeam(Player, Settings, SourcePRI, SmokeLocation, HitLocation, HitNormal);
	PlayRing(Player, Settings, SourcePRI, HitLocation, HitNormal);
}

static function PlayBeam(
	PlayerPawn Player,
	ClientSettings Settings,
	PlayerReplicationInfo SourcePRI,
	vector SmokeLocation,
	vector HitLocation,
	vector HitNormal
) {
	local ClientShockBeam Smoke;
	local Vector DVector;
	local int NumPoints;
	local rotator SmokeRotation;
	local vector MoveAmount;

	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector) / 135.0;
	if ( NumPoints < 1 )
		return;
	SmokeRotation = rotator(DVector);
	SmokeRotation.roll = Rand(65535);

	Smoke = class'ClientShockBeam'.static.AllocBeam(Player);
	if (Smoke == none) return;
	Smoke.SetLocation(SmokeLocation);
	Smoke.SetRotation(SmokeRotation);
	MoveAmount = DVector / NumPoints;

	Smoke.SetProperties(
		-1,
		1,
		1,
		0.27,
		MoveAmount,
		NumPoints - 1,
		Settings.bBeamEnableLight);
}

static function PlayRing(
	PlayerPawn Player,
	ClientSettings Settings,
	PlayerReplicationInfo SourcePRI,
	vector HitLocation,
	vector HitNormal
) {
	local Actor A;
	A = Player.Spawn(class'ut_RingExplosion5',,, HitLocation+HitNormal*8,rotator(HitNormal));
	A.RemoteRole = ROLE_None;
	// DO not allow other SSRingtypes in SDOM
}