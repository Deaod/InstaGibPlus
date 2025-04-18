class ClientShockBeam extends Effects;

// Settings
var int Team;
var float Size;
var float Curve;
var float Duration;
var vector MoveAmount;
var int NumPuffs;
var bool bBeamEnableLight;

//
var float TimeLeft;

var ClientShockBeam Next;
var ClientShockBeam Free;

simulated function Tick(float DeltaTime) {
    if (Level.NetMode != NM_DedicatedServer) {
        ScaleGlow = (TimeLeft / Duration) ** Curve;

        AmbientGlow = ScaleGlow * 210;
        if (Team >= 0)
            LightBrightness = ScaleGlow * 128;

        TimeLeft -= DeltaTime;
        if (TimeLeft <= 0.0) {
            FreeBeam(self);
        }
    }
}

simulated function SetProperties(int pTeam, float pSize, float pCurve, float pDuration, vector pMoveAmount, int pNumPuffs, bool pbBeamEnableLight) {
    Team = pTeam;
    Size = pSize;
    Duration = pDuration;
    Curve = pCurve;
    MoveAmount = pMoveAmount;
    NumPuffs = pNumPuffs;
    bBeamEnableLight = pbBeamEnableLight;

    if (Team >= 0) {
        Mesh = LodMesh'Botpack.Shockbm';
        if (bBeamEnableLight && Level.bHighDetailMode)
            LightType = LT_Steady;
        else
            LightType = LT_None;
        LightEffect = LE_NonIncidence;
        LightBrightness = 192;
        LightSaturation = 64;
        LightRadius = 6;
    }

    switch (Team) {
        case -1:
            // Dont
            break;

        case 0:
            Texture = Texture'BotPack.Translocator.Tranglow';
            LightHue = 0;
            break;

        case 1:
            Texture = Texture'BotPack.Translocator.Tranglowb';
            LightHue = 150;
            LightBrightness = 224;
            break;

        case 2:
            Texture = Texture'BotPack.Translocator.Tranglowg';
            LightHue = 75;
            break;

        case 3:
            Texture = Texture'BotPack.Translocator.Tranglowy';
            LightHue = 40;
            break;
    }
    DrawScale = 0.44 * Size;
    TimeLeft = Duration;

    if (Level.NetMode != NM_DedicatedServer)
        SetTimer(0.05, false);
}

simulated function Timer() {
    local ClientShockBeam r;

    if (NumPuffs > 0) {
        r = AllocBeam(PlayerPawn(Owner));
        r.SetLocation(Location + MoveAmount);
        r.SetRotation(Rotation);
        r.SetProperties(Team,Size,Curve,Duration,MoveAmount, NumPuffs - 1, bBeamEnableLight);
    }
}

static final function ResetBeam(ClientShockBeam Beam) {
    Beam.Texture = default.Texture;
    Beam.Mesh = default.Mesh;
    Beam.LightType = default.LightType;
    Beam.LightEffect = default.LightEffect;
    Beam.LightBrightness = default.LightBrightness;
    Beam.LightSaturation = default.LightSaturation;
    Beam.LightRadius = default.LightRadius;
    Beam.LightHue = default.LightHue;
}

static final function ClientShockBeam AllocBeam(PlayerPawn P) {
    local ClientShockBeam Beam;

    if (default.Free != none) {
        Beam = default.Free;
        default.Free = Beam.Next;
        Beam.Next = none;

        Beam.bHidden = false;
        Beam.Enable('Tick');
    } else {
        Beam = P.Spawn(class'ClientShockBeam', P);
    }

    ResetBeam(Beam);
    return Beam;
}

static final function FreeBeam(ClientShockBeam Beam) {
    Beam.bHidden = true;
    Beam.LightType = LT_None;
    Beam.Disable('Tick');

    Beam.Next = default.Free;
    default.Free = Beam;
}

static final function Cleanup() {
    default.Free = none;
}


defaultproperties
{
    Team=0
    Size=0.0000000
    Curve=0.0000000
    duration=0.0000000
    MoveAmount=(X=0.0000000,Y=0.0000000,Z=0.0000000)
    NumPuffs=0
    bBeamEnableLight=false
    TimeLeft=0.0000000
    Next=none
    Free=none
    Physics=5
    RemoteRole=0
    Rotation=(Pitch=0,Yaw=0,Roll=20000)
    DrawType=2
    Style=3
    Texture=Texture'Botpack.Effects.jenergy2'
    Mesh=LodMesh'Botpack.Shockbm'
    DrawScale=0.4400000
    bUnlit=true
    bParticles=true
    bFixedRotationDir=true
    RotationRate=(Pitch=0,Yaw=0,Roll=1000000)
    DesiredRotation=(Pitch=0,Yaw=0,Roll=20000)
}