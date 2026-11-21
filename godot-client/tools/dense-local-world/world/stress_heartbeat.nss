// ARE OnHeartbeat. The entry script also runs the first tick immediately.
const int DOOR_COUNT = 12;
const int DOOR_BANK = 3;
const int MECHANICAL_COUNT = 24;
const int ROUTE_PULSES = 8;

int CurrentRun(object oArea, object oPlayer, int nEntry)
{
    return GetIsObjectValid(oPlayer) && GetArea(oPlayer) == oArea
        && GetLocalObject(oArea, "DenseStressPlayer") == oPlayer
        && GetLocalInt(oArea, "DenseStressEntry") == nEntry;
}

object OwnedObject(object oArea, string sTag, int nType)
{
    object oObject = GetObjectByTag(sTag);
    if (GetObjectType(oObject) == nType && GetArea(oObject) == oArea)
        return oObject;
    return OBJECT_INVALID;
}

void SetDenseDoor(object oArea, string sArea, int nIndex, int bOpen)
{
    string sIndex = IntToString(nIndex);
    object oDoor = OwnedObject(oArea, sArea + "_door_" + sIndex, OBJECT_TYPE_DOOR);
    if (!GetIsObjectValid(oDoor))
        return;

    SetLocalInt(oDoor, "DenseStressExpectedDoor", 0);
    SetLocalInt(oDoor, "DenseStressDoorQueued", 0);
    if (GetIsOpen(oDoor) == bOpen)
        return;
    SetLocalInt(oDoor, "DenseStressExpectedDoor", bOpen ? 1 : 2);

    // A door action belongs to the fixture creature next to that door.
    object oAttendant = OwnedObject(oArea, sArea + "_door_actor_" + sIndex, OBJECT_TYPE_CREATURE);
    if (!GetIsObjectValid(oAttendant) || GetIsPC(oAttendant))
        return;
    float fDistance = GetDistanceToObject(oDoor, oAttendant);
    if (fDistance < 0.0 || fDistance > 1.6)
        return;
    if (bOpen)
        AssignCommand(oAttendant, ActionOpenDoor(oDoor));
    else
        AssignCommand(oAttendant, ActionCloseDoor(oDoor));
    SetLocalInt(oDoor, "DenseStressDoorQueued", 1);
}

void ReportDenseDoors(object oArea, object oPlayer, string sArea, int nEntry,
    int nFirst, int nLast, string sPhase)
{
    if (!CurrentRun(oArea, oPlayer, nEntry))
        return;
    int nOpened = 0;
    int nClosed = 0;
    int nRequested = 0;
    int nQueued = 0;
    int nMissing = 0;
    int nIndex;
    for (nIndex = nFirst; nIndex < nLast; nIndex++)
    {
        object oDoor = OwnedObject(oArea, sArea + "_door_" + IntToString(nIndex), OBJECT_TYPE_DOOR);
        if (!GetIsObjectValid(oDoor))
            continue;
        int nState = GetLocalInt(oDoor, "DenseStressExpectedDoor");
        if (nState == 0)
            continue;
        nRequested++;
        nQueued += GetLocalInt(oDoor, "DenseStressDoorQueued");
        if (nState == 1 && GetIsOpen(oDoor))
            nOpened++;
        else if (nState == 2 && !GetIsOpen(oDoor))
            nClosed++;
        else
            nMissing++;
    }
    WriteTimestampedLogEntry("DenseStress " + sArea + " " + sPhase + " entry=" + IntToString(nEntry)
        + " requested=" + IntToString(nRequested) + " queued=" + IntToString(nQueued)
        + " opened=" + IntToString(nOpened)
        + " closed=" + IntToString(nClosed) + " pending=" + IntToString(nMissing));
}

void PulseDenseDoors(object oArea, object oPlayer, string sArea, int nEntry, int nPulse)
{
    if (!CurrentRun(oArea, oPlayer, nEntry) || nPulse >= ROUTE_PULSES)
        return;

    int nFirst = (nPulse * DOOR_BANK) % DOOR_COUNT;
    int bInvert = nPulse * DOOR_BANK < DOOR_COUNT;
    int nIndex;
    for (nIndex = nFirst; nIndex < nFirst + DOOR_BANK; nIndex++)
        SetDenseDoor(oArea, sArea, nIndex, (nIndex + bInvert) % 2);
    if (nPulse == 0)
        DelayCommand(3.0, ReportDenseDoors(oArea, oPlayer, sArea, nEntry, nFirst, nFirst + DOOR_BANK, "route"));
    DelayCommand(2.0, PulseDenseDoors(oArea, oPlayer, sArea, nEntry, nPulse + 1));
}

void WaitForDenseRoute(object oArea, object oPlayer, string sArea, int nEntry, vector vEntry, int nChecks)
{
    if (!CurrentRun(oArea, oPlayer, nEntry) || nChecks >= 1000)
        return;
    vector vNow = GetPosition(oPlayer);
    float fDx = vNow.x - vEntry.x;
    float fDy = vNow.y - vEntry.y;
    if (fDx * fDx + fDy * fDy >= 0.5625)
    {
        PulseDenseDoors(oArea, oPlayer, sArea, nEntry, 0);
        return;
    }
    DelayCommand(0.5, WaitForDenseRoute(oArea, oPlayer, sArea, nEntry, vEntry, nChecks + 1));
}

void PulseDenseProps(object oArea, string sArea, int nPhase)
{
    int nIndex;
    for (nIndex = 0; nIndex < MECHANICAL_COUNT; nIndex++)
    {
        object oProp = OwnedObject(oArea, sArea + "_mech_" + IntToString(nIndex), OBJECT_TYPE_PLACEABLE);
        if (!GetIsObjectValid(oProp))
            continue;
        int nAnimation = (nIndex + nPhase) % 2 == 0
            ? ANIMATION_PLACEABLE_ACTIVATE : ANIMATION_PLACEABLE_DEACTIVATE;
        AssignCommand(oProp, PlayAnimation(nAnimation));
    }
}

void main()
{
    object oArea = OBJECT_SELF;
    string sArea = GetResRef(oArea);
    if (sArea != "dense_a" && sArea != "dense_b")
        return;
    int nEntry = GetLocalInt(oArea, "DenseStressEntry");
    object oPlayer = GetLocalObject(oArea, "DenseStressPlayer");
    if (nEntry == 0 || !CurrentRun(oArea, oPlayer, nEntry))
        return;

    if (GetLocalInt(oArea, "DenseStressActiveEntry") != nEntry)
    {
        SetLocalInt(oArea, "DenseStressActiveEntry", nEntry);
        SetLocalInt(oArea, "DenseStressPropPhase", 0);
        int nDoor;
        for (nDoor = 0; nDoor < DOOR_COUNT; nDoor++)
            SetDenseDoor(oArea, sArea, nDoor, nDoor % 2);
        DelayCommand(3.0, ReportDenseDoors(oArea, oPlayer, sArea, nEntry, 0, DOOR_COUNT, "entry"));
        DelayCommand(0.5, WaitForDenseRoute(oArea, oPlayer, sArea, nEntry, GetPosition(oPlayer), 0));
    }

    int nPhase = GetLocalInt(oArea, "DenseStressPropPhase");
    PulseDenseProps(oArea, sArea, nPhase);
    SetLocalInt(oArea, "DenseStressPropPhase", 1 - nPhase);
}
