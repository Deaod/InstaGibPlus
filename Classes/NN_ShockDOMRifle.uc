class NN_ShockDOMRifle extends NN_ShockRifle;

simulated function bool NN_ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
    local bbPlayer bbP;
    if (Owner.IsA('Bot'))
        return false;

    bbP = bbPlayer(Owner);
    if (bbP == none) return false;

    super.NN_ProcessTraceHit(Other, HitLocation, HitNormal, X, Y, Z);
    class'bbPlayerStatics'.static.PlayClientHitResponse(Pawn(Owner), Other, HitDamage, MyDamageType);
    
    return false;
}

simulated function RenderOverlays(Canvas Canvas)
{
    local bbPlayer bbP;

    Super(ShockRifle).RenderOverlays(Canvas);

    yModInit();

    bbP = bbPlayer(Owner);
    if (bNewNet && Role < ROLE_Authority && bbP != None)
    {
        if (bbP.bFire != 0 && !IsInState('ClientFiring'))
            ClientFire(1);
        else if (bbP.bAltFire != 0 && !IsInState('ClientFiring'))
            ClientFire(1);
    }
}

function AltFire( float Value )
{
    Fire(Value);
}

simulated function bool ClientAltFire(float Value)
{
    return ClientFire(Value);
}

simulated function PlaySelect ()
{
    return;
}

defaultproperties
{
    bNewNet=True
    PickupAmmoCount=50
    AmmoName=Class'ST_ShockCoreSDOM'
}