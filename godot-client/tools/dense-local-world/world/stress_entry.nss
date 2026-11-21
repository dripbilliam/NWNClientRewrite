void main()
{
    object oPlayer = GetEnteringObject();
    if (!GetIsPC(oPlayer))
        return;

    SetLocalObject(OBJECT_SELF, "DenseStressPlayer", oPlayer);
    SetLocalInt(OBJECT_SELF, "DenseStressEntry", GetLocalInt(OBJECT_SELF, "DenseStressEntry") + 1);
    ExecuteScript("stress_heartbeat", OBJECT_SELF);
}
