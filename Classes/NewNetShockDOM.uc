class NewNetShockDOM extends Arena;
// Description="ShockArena with lag-compensated sDOM Shock Rifle"

var IGPlus_WeaponImplementation WImp;
var string PreFix;

function InitializeSettings() {
    WImp = Spawn(class'IGPlus_WeaponImplementationBase');
    WImp.InitWeaponSettings("WeaponSettingsNewNet");
}

function PreBeginPlay() {    
    PreFix = class'StringUtils'.static.PackageOfObject(self);
    Log("NewNetShockDOM determined prefix="$PreFix, 'IGPlus');
    WeaponString=PreFix$".NN_ShockDOMRifle";
    AmmoString=PreFix$".ST_ShockCoreSDOM";

    super.PreBeginPlay();    

    InitializeSettings();
}

function bool AlwaysKeep(Actor Other)
{
    if ((Other.IsA('NN_Armor2') || Other.IsA('NN_ThighPads')))
        return true;

    return Super.AlwaysKeep(Other);
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    super.CheckReplacement(Other, bSuperRelevant);

    if (Other.IsA('Weapon'))
        return CheckReplaceWeapon(Other) == false;

    if (Other.IsA('Armor2') || Other.IsA('Armor'))
    {
        ReplaceWith( Other, PreFix$".NN_Armor2" );
        return false;
    } 
    else if (Other.IsA('ThighPads') || Other.IsA('KevlarSuit'))
    {
        ReplaceWith( Other, PreFix$".NN_ThighPads" );
        return false;
    }

    if (Other.IsA('Pickup'))
        return CheckReplacePickups(Other) == false;

    return true;
}

function bool CheckReplaceWeapon(Actor A) {
    local Weapon W;
    local WeaponSettings WS;

    W = Weapon(A);
    WS = WImp.WeaponSettings;

    if (W == none)
        return false;

    if (W.Class == class'NN_ShockDOMRifle') {
        return false;
    }

    if (W.Class == class'ShockRifle' || W.Class == class'ASMD' || W.Class == class'NN_ShockRifle') {
        return DoReplace(W, class'NN_ShockDOMRifle');
    } else {
        W.destroy();
    }

    return false;
}

function bool CheckReplacePickups(Actor A) {
    local Pickup P;
    local WeaponSettings WS;

    P = Pickup(A);
    WS = WImp.WeaponSettings;

    if (P == none) return false;
    else if (P.Class == class'Miniammo')        {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'BioAmmo')         {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'ShockCore')       {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'PAmmo')           {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'BladeHopper')     {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'FlakAmmo')        {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'RocketPack')      {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'BulletBox')       {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }
    else if (P.Class == class'WarHeadAmmo')     {  return DoReplacePickup(P, class'ST_ShockCoreSDOM'); }

    else if (P.Class == class'HealthVial')     { return DoReplacePickup(P, class'ST_HealthVialSDOM'); }
    else if (P.Class == class'MedBox')         { return DoReplacePickup(P, class'ST_MedBoxSDOM'); }
    else if (P.Class == class'HealthPack')     { return DoReplacePickup(P, class'ST_HealthPackSDOM'); }
    else if (P.Class == class'UDamage')        { return DoReplacePickup(P, class'ST_UDamageSDOM'); }

    return false;
}

function bool DoReplacePickup(Pickup Other, class<Pickup> ReplacementClass) {
    local Pickup P;

    P = Other.Spawn(ReplacementClass, Other.Owner, Other.Tag);
    if (P != none) {
        // TODO: What is this
        /*if (DelaySpawnNotifyReplace <= 0)
            SN.SetReplace(Other, P);*/
        return true;
    }
    return false;
}

function bool DoReplace(Weapon Other, class<Weapon> ReplacementClass) {
    local Weapon W;

    W = Other.Spawn(ReplacementClass, Other.Owner, Other.Tag);
    if (W != none) {
        W.SetCollisionSize(Other.CollisionRadius, Other.CollisionHeight);
        W.Tag = Other.Tag;
        W.Event = Other.Event;
        if (Other.MyMarker != none) {
                W.MyMarker = Other.MyMarker;
                W.MyMarker.markedItem = W;
        }
        W.bHeldItem = Other.bHeldItem;
        W.RespawnTime = Other.RespawnTime;
        W.PickupAmmoCount = Other.PickupAmmoCount;
        W.bRotatingPickup = Other.bRotatingPickup;

        // TODO: What is this
        /*if (DelaySpawnNotifyReplace <= 0)
            SN.SetReplace(Other, W);    */
        return true;
    }
    return false;
}


defaultproperties
{
    bReplaceWeapons=True
    WeaponName=NN_ShockDOMRifle
    AmmoName=ST_ShockCoreSDOM
    DefaultWeapon=class'NN_ShockDOMRifle'
}