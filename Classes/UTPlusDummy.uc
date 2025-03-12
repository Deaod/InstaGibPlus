class UTPlusDummy extends Actor;

var Pawn Actual;
var float LatestClientTimeStamp;
var float EyeHeight;
var float BaseEyeHeight;

struct DummyData {
	var vector Loc, Vel, Acc;
	var rotator Rot, VR;
	var float BaseEyeHeight;
	var float EyeHeight;
	var float CollisionRadius;
	var float CollisionHeight;
	var float ServerTimeStamp;
	var float ClientTimeStamp;
};

var DummyData Data[32];
var int DataIndex;

var bool bCompActive;

var UTPlusDummy Next;

function FillData(out DummyData D) {
	D.Loc = Actual.Location;
	D.Vel = Actual.Velocity;
	D.Acc = Actual.Acceleration;
	D.Rot = Actual.Rotation;
	D.VR = Actual.ViewRotation;
	D.BaseEyeHeight = Actual.BaseEyeHeight;
	D.EyeHeight = Actual.EyeHeight;
	D.CollisionRadius = Actual.CollisionRadius;
	D.CollisionHeight = Actual.CollisionHeight;
	D.ServerTimeStamp = Level.TimeSeconds;
	if (Actual.IsA('PlayerPawn'))
		D.ClientTimeStamp = PlayerPawn(Actual).CurrentTimeStamp;
}

event Tick(float DeltaTime) {
	super.Tick(DeltaTime);

	if (Actual == none || Actual.bDeleteMe) {
        Disable('Tick');
    }

	if (Actual.IsA('PlayerPawn') == false || PlayerPawn(Actual).CurrentTimeStamp > LatestClientTimeStamp) {
		if (Actual.IsA('PlayerPawn'))
			LatestClientTimeStamp = PlayerPawn(Actual).CurrentTimeStamp;

		FillData(Data[DataIndex]);
		DataIndex += 1;
		if (DataIndex == arraycount(Data))
			DataIndex = 0;
	}
}
function vector LerpVector(float Alpha, vector A, vector B) {
    return A + (B - A) * Alpha;
}

function CompStart(int Ping) {
    local float TargetTimeStamp;
    local int I;
    local int Next;
    local float Alpha;
    local float TimeDelta;
    local float Distance;

	if (Actual == none || Actual.bDeleteMe)
    	return;

    TargetTimeStamp = Level.TimeSeconds - 0.001*Ping*Level.TimeDilation;

    I = DataIndex - 1;
    if (I < 0)
        I += arraycount(Data);
    do {
        Next = I - 1;
        if (Next < 0)
            Next += arraycount(Data);

        if (Data[I].ServerTimeStamp <= TargetTimeStamp) {
            CompSwap(
                Data[I].Loc + Data[I].Vel * (TargetTimeStamp - Data[I].ServerTimeStamp),
                Data[I].EyeHeight,
                Data[I].BaseEyeHeight,
                Data[I].CollisionRadius,
                Data[I].CollisionHeight
            );
            return;
        } else if (Data[Next].ServerTimeStamp <= TargetTimeStamp) {
            // Calculate time and distance for continuity check
            TimeDelta = Data[I].ServerTimeStamp - Data[Next].ServerTimeStamp;
            Distance = VSize(Data[I].Loc - Data[Next].Loc);

            // Continuity check
            if (TimeDelta > 0 && Distance / TimeDelta <= 2500) { // Threshold for continuous motion
                Alpha = (TargetTimeStamp - Data[Next].ServerTimeStamp) / TimeDelta;
                CompSwap(
                    LerpVector(Alpha, Data[Next].Loc, Data[I].Loc),
                    Data[Next].EyeHeight,
                    Data[Next].BaseEyeHeight,
                    Data[Next].CollisionRadius,
                    Data[Next].CollisionHeight
                );
            } else {
                // Use original velocity extrapolation
                CompSwap(
                    Data[Next].Loc + Data[Next].Vel * (TargetTimeStamp - Data[Next].ServerTimeStamp),
                    Data[Next].EyeHeight,
                    Data[Next].BaseEyeHeight,
                    Data[Next].CollisionRadius,
                    Data[Next].CollisionHeight
                );
            }
            return;
        }

        I = Next;
    } until(I == DataIndex);

    // Fallback to last known info
    CompSwap(
        Data[I].Loc,
        Data[I].EyeHeight,
        Data[I].BaseEyeHeight,
        Data[I].CollisionRadius,
        Data[I].CollisionHeight
    );
}

function TakeDamage(
    int Damage,
    Pawn InstigatedBy,
    Vector Hitlocation,
    Vector Momentum,
    name DamageType
) {
    if (Actual != none)
        Actual.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType);
}

function CompSwap(vector Loc, float EH, float BEH, float CR, float CH) {
	Actual.SetCollision(false, false, false);
	SetLocation(Loc);
	EyeHeight = EH;
	BaseEyeHeight = BEH;
	SetCollisionSize(CR, CH);
	SetCollision(true, false, false);
	bProjTarget=true;
	bCompActive = true;
}

function CompEnd() {
	if (bCompActive) {
		bCompActive = false;
		SetCollision(false, false, false);
		bProjTarget=false;
		Actual.SetCollision(true, true, true);
	}
}

simulated function bool AdjustHitLocation(out vector HitLocation, vector TraceDir) {
	local float adjZ, maxZ;

	TraceDir = Normal(TraceDir);
	HitLocation = HitLocation + 0.5 * CollisionRadius * TraceDir;
	if (BaseEyeHeight == Actual.Default.BaseEyeHeight)
		return true;

	maxZ = Location.Z + EyeHeight + 0.25 * CollisionHeight;
	if (HitLocation.Z > maxZ)	{
		if (TraceDir.Z >= 0)
			return false;
		adjZ = (maxZ - HitLocation.Z)/TraceDir.Z;
		HitLocation.Z = maxZ;
		HitLocation.X = HitLocation.X + TraceDir.X * adjZ;
		HitLocation.Y = HitLocation.Y + TraceDir.Y * adjZ;
		if (VSize(vect(1,1,0) * (HitLocation - Location)) > CollisionRadius)
			return false;
	}
	return true;
}


defaultproperties {
	bHidden=True
	RemoteRole=ROLE_None;
}