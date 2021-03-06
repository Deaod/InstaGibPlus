class IGPlus_DeathMessagePlus extends LocalMessagePlus;

var localized string KilledString;

static function string GetString(
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
) {
    local class<TournamentGameInfo> TGI;

    if (RelatedPRI_1 != none && RelatedPRI_1.Level.Game != none)
        TGI = class<TournamentGameInfo>(RelatedPRI_1.Level.Game.class);
    if (TGI == none)
        TGI = class'TournamentGameInfo';

    switch (Switch)
    {
        case 0:
            if (RelatedPRI_1 == None)
                return "";
            if (RelatedPRI_1.PlayerName == "")
                return "";
            if (RelatedPRI_2 == None)
                return "";
            if (RelatedPRI_2.PlayerName == "")
                return "";
            if (Class<Weapon>(OptionalObject) == None)
            {
                return "";
            }
            return class'GameInfo'.Static.ParseKillMessage(
                RelatedPRI_1.PlayerName,
                RelatedPRI_2.PlayerName,
                Class<Weapon>(OptionalObject).Default.ItemName,
                Class<Weapon>(OptionalObject).Default.DeathMessage
            );
            break;
        case 1: // Suicided
            if (RelatedPRI_1 == None)
                return "";
            if (RelatedPRI_1.bIsFemale)
                return RelatedPRI_1.PlayerName$TGI.Default.FemaleSuicideMessage;
            else
                return RelatedPRI_1.PlayerName$TGI.Default.MaleSuicideMessage;
            break;
        case 2: // Fell
            if (RelatedPRI_1 == None)
                return "";
            return RelatedPRI_1.PlayerName$TGI.Default.FallMessage;
            break;
        case 3: // Eradicated (Used for runes, but not in UT)
            if (RelatedPRI_1 == None)
                return "";
            return RelatedPRI_1.PlayerName$TGI.Default.ExplodeMessage;
            break;
        case 4: // Drowned
            if (RelatedPRI_1 == None)
                return "";
            return RelatedPRI_1.PlayerName$TGI.Default.DrownedMessage;
            break;
        case 5: // Burned
            if (RelatedPRI_1 == None)
                return "";
            return RelatedPRI_1.PlayerName$TGI.Default.BurnedMessage;
            break;
        case 6: // Corroded
            if (RelatedPRI_1 == None)
                return "";
            return RelatedPRI_1.PlayerName$TGI.Default.CorrodedMessage;
            break;
        case 7: // Mortared
            if (RelatedPRI_1 == None)
                return "";
            return RelatedPRI_1.PlayerName$TGI.Default.MortarMessage;
            break;
        case 8: // Telefrag
            if (RelatedPRI_1 == None)
                return "";
            if (RelatedPRI_2 == None)
                return "";
            return class'GameInfo'.Static.ParseKillMessage(
                RelatedPRI_1.PlayerName,
                RelatedPRI_2.PlayerName,
                class'Translocator'.Default.ItemName,
                class'Translocator'.Default.DeathMessage
            );
            break;
    }
}

static function ClientReceive(
    PlayerPawn P,
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
) {
    local MutKillFeed KFMut;
    if (P.myHUD != None) {
        foreach P.AllActors(class'MutKillFeed', KFMut)
            break;
        if (P.IsA('bbPlayer') == false ||
            bbPlayer(P).Settings.bEnableKillFeed == false ||
            KFMut == none
        ) {
            P.myHUD.LocalizedMessage(Default.Class, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
        }
    }

    if (Default.bBeep && P.bMessageBeep)
        P.PlayBeepSound();

    if (Default.bIsConsoleMessage) {
        if ((P.Player != None) && (P.Player.Console != None))
            P.Player.Console.AddString(Static.GetString(Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject));
    }

    if (P == RelatedPRI_1.Owner || (P.ViewTarget != none && P.ViewTarget == RelatedPRI_1.Owner)) {
        // Interdict and send the child message instead.
        if ( P.myHUD != None ) {
            P.myHUD.LocalizedMessage(Default.ChildMessage, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
        }

        if (RelatedPRI_1.Owner.IsA('TournamentPlayer')) { // ie. not a Bot
            if ((RelatedPRI_1 != RelatedPRI_2) && (RelatedPRI_2 != None)) {
                if ((P.Level.TimeSeconds - TournamentPlayer(RelatedPRI_1.Owner).LastKillTime < 3) && (Switch != 1)) {
                    TournamentPlayer(RelatedPRI_1.Owner).MultiLevel++;
                    P.ReceiveLocalizedMessage( class'MultiKillMessage', TournamentPlayer(RelatedPRI_1.Owner).MultiLevel );
                } else {
                    TournamentPlayer(RelatedPRI_1.Owner).MultiLevel = 0;
                }
                TournamentPlayer(RelatedPRI_1.Owner).LastKillTime = P.Level.TimeSeconds;
            } else {
                TournamentPlayer(RelatedPRI_1.Owner).MultiLevel = 0;
            }
        }
        if (ChallengeHUD(P.myHUD) != None)
            ChallengeHUD(P.myHUD).ScoreTime = P.Level.TimeSeconds;
    } else if (RelatedPRI_2 != none && (P == RelatedPRI_2.Owner || (P.ViewTarget != none && P.ViewTarget == RelatedPRI_2.Owner))) {
        P.ReceiveLocalizedMessage(class'VictimMessage', 0, RelatedPRI_1);
    }
}

defaultproperties
{
     KilledString="was killed by"
     ChildMessage=Class'Botpack.KillerMessagePlus'
     DrawColor=(R=255,G=0,B=0)
}
