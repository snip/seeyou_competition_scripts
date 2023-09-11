Program eGlide_Elapsed_time_scoring_with_Distance_Handicapping_E4Glide;

const 
  Rmin = 1000;         // Sector radius in meters that will be used by highest handicapped gliders.
  Rfinish = 0;        // Finish ring radius. Use zero if finish line is used.
  ManualRadius = true; // If this is set to true, you must enter R_hcap for each Handicap factor manually in function Radius(Hcap)
  PowerTreshold = 20; // In Watts [W]. If Current*Voltage is less than that, it won't count towards consumed energy.
  RefVoltage = 110;   // Fallback if nothing else is known about voltage used when engine is running
  RefCurrent = 200;   // Fallback if nothing is known about current consumption
  RefPower = 120*280; // Fallback when only ENL is available (Antares in case of E2Glide 2020)
  FreeAllowance = 20000; //20k is to prevent script applying penalties as allowed energy is depending on the mass => manual check for the time being // Watt-hours. No penalty if less power was consumed
  EnginePenaltyPerSec = 1;    // Penalty in seconds per Watt-hour consumed over Free Allowance. 1000 Wh of energy allows you to cruise for 15 minutes.
  Fa = 1.2;           // Max time after fastest finisher
  MaxDelay = 20*60;   // Maximum delay for finishers and outlanders in seconds

var
  fr_Hmax,
  Dm, D1,
  Dt, n1, n2, n3, n4, N, D0, Vo, T0, Tm,
  Pm, Pdm, Pvm, Pn, F, Fcr, Day: Double;
  D, H, Dh, M, T, Dc, Pd, V, Vh, Pv, S, R_hcap, PilotDis : double;
  PmaxDistance, PmaxTime, PilotEnergyConsumption, CurrentPower, PilotEngineTime, EnginePenalty, ScoringFinish  : double;
  i,j, minIdx : integer;
  str : String;
  Interval, NumIntervals, GateIntervalPos, NumIntervalsPos, PilotStartInterval, PilotStartTime, PilotPEVStartTime, StartTimeBuffer, PilotLegs, TaskPoints : Integer;
  AAT, TPRounded : boolean;
  Auto_Hcaps_on : boolean;

  



function Radius( Hcap:double ):double;
var 
  i : integer;
  R_hcap, Hmax, TaskDis, TaskLegs : double;
begin
  TaskDis := Task.TotalDis;
  //TODO Get rid of TaskLegs. It is just TaskPoints-1
  TaskLegs := GetArrayLength(Task.Point)-1;

  Hmax := 0;
  for i := 0 to GetArrayLength(Pilots)-1 do 
  begin
    If not Pilots[i].isHC Then
    begin
      If Pilots[i].Hcap > Hmax Then Hmax := Pilots[i].Hcap; // Hightest Handicap of all competitors in the class
    end;
  end;
  If Hmax=0 Then 
  begin
    Info1 := '';
	  Info2 := 'Error: Highest handicap is zero!';
  	Exit;
  end;
  fr_Hmax := Hmax;
  if ManualRadius then 
  begin
    case Hcap of
      // You must enter one line for each Handicap factor in the competition for each competition day
      // All values are in meters
      111 : R_hcap := 2900;
      113 : R_hcap := 2600;
      119 : R_hcap := 1600;
      121 : R_hcap := 1300;
      122 : R_hcap := 1100;
      122 : R_hcap := 1000;
    else
      begin
        R_hcap := Rmin;
      end;
    end;
  end
  else
  begin
    //TODO This is true for all 180 degree turns in the task
    //TODO Find a solution for sectors with turns less than 180 degrees
    R_hcap := TaskDis/2/(TaskLegs-1)*(1-(Hcap/Hmax))+Hcap/Hmax*Rmin;
    R_hcap := Round(R_hcap/100)*100;
  end;

  Radius := R_hcap;
end;

begin
  // initial checks
  if GetArrayLength(Pilots) <= 1 then
    exit; 

  // Calculate Distance flown for each pilot depending Radius(Hcap)
  TaskPoints := GetArrayLength(Task.Point);
  for i:=0 to GetArrayLength(Pilots)-1 do
  begin
    PilotDis := 0;
    PilotLegs := GetArrayLength(Pilots[i].Leg);
    Pilots[i].Warning := '';
  
    // Calculate Handicapped turnpoint radius for this particular pilot's Handicap
    R_hcap := Radius(Pilots[i].hcap);

    //! Debug output
    Pilots[i].Warning := Pilots[i].Warning + 'Hmax: ' + FormatFloat('0',fr_Hmax);
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'R_hcap: ' + FormatFloat('0',R_hcap)+' m; ';
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'Task points: ' + IntToStr(TaskPoints)+'; ';
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'Pilot legs: ' + IntToStr(GetArrayLength(Pilots[i].Leg))+'; ';
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'Pilot legsT: ' + IntToStr(GetArrayLength(Pilots[i].LegT))+'; ';
    for j:=0 to GetArrayLength(Pilots[i].Leg)-1 do
    begin
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'Leg['+IntToStr(j)+']: DisToTP = ' + FormatFloat('0',Pilots[i].Leg[j].DisToTp) + '; PilotLegDis = ' + FormatFloat('0',Pilots[i].Leg[j].d) + '; LegDis = ' + FormatFloat('0',Task.Point[j].d);
    end;


    // Calculate flown distance according to Radius(Pilots[i].hcap) = R_hcap
    TPRounded := true;
    if GetArrayLength(Pilots[i].Leg) > 0 then
    begin
      ScoringFinish := 0;
      for j:=0 to GetArrayLength(Pilots[i].Leg)-1 do
      begin
        if TPRounded then
        begin
          case j of
            // Start leg
            0 : 
            begin 
              // If it was successfully completed, subtract R_hcap. If not, just count what was flown and set TPRounded to false.
              if (PilotLegs > j+1) then
              begin
                if Pilots[i].Leg[j+1].DisToTP <= R_hcap then
                begin
                  PilotDis := PilotDis + Pilots[i].Leg[j].d - R_hcap;
                  //! Debug output
                  Pilots[i].Warning := Pilots[i].Warning + #10 + 'First leg OK';
                end
                else
                begin
                  TPRounded := false;
                  PilotDis := PilotDis + Pilots[i].Leg[j].d - Pilots[i].Leg[j+1].DisToTP;
                  ScoringFinish := Pilots[i].Leg[j].finish;
                  //! Debug output
                  Pilots[i].Warning := Pilots[i].Warning + #10 + 'First leg in sector but > R_hcap: ' + FormatFloat('0',ScoringFinish);
                end;
              end
              else
              begin
                TPRounded := false;
                PilotDis := PilotDis + Pilots[i].Leg[j].d;
                ScoringFinish := Pilots[i].Leg[j].finish;
                //! Debug output
                Pilots[i].Warning := Pilots[i].Warning + #10 + 'First leg did not reach 1st sector:' + FormatFloat('0',ScoringFinish);
              end;
            end;

            // Finish leg
            (TaskPoints-2)  : 
            begin 
              // If it was successfully completed, subtract R_hcap. If not, just count what was flown and set TPRounded to false.
              if Pilots[i].finish > 0 then
              begin
                PilotDis := PilotDis + Pilots[i].Leg[j].d - R_hcap - Rfinish; 
                //! Debug output
                Pilots[i].Warning := Pilots[i].Warning + #10 + 'Finish leg OK';
              end
              else
              begin
                TPRounded := false;
                ScoringFinish := Pilots[i].Leg[j].finish;
                PilotDis := PilotDis + Pilots[i].Leg[j].d; 
                Pilots[i].Warning := Pilots[i].Warning + #10 + 'Finish leg not completed';
              end;
            end;
          else
            begin
              // Intermediate legs
              // If it was successfully completed, subtract R_hcap. If not, just count what was flown and set TPRounded to false.
              if (PilotLegs > j+1) then
              begin
                if Pilots[i].Leg[j+1].DisToTP <= R_hcap then
                begin
                  PilotDis := PilotDis + Pilots[i].Leg[j].d - 2*R_hcap;
                  //! Debug output
                  Pilots[i].Warning := Pilots[i].Warning + #10 + IntToStr(j+1) + '. leg OK';
                end
                else
                begin
                  TPRounded := false;
                  PilotDis := PilotDis + Pilots[i].Leg[j].d - Pilots[i].Leg[j+1].DisToTP;
                  ScoringFinish := Pilots[i].Leg[j].finish;
                  //! Debug output
                  Pilots[i].Warning := Pilots[i].Warning + #10 + IntToStr(j+1) + '. leg in sector but > R_hcap: ' + FormatFloat('0',ScoringFinish);
                end;
              end
              else
              begin
                PilotDis := PilotDis + Pilots[i].Leg[j].d - R_hcap;
                TPRounded := false;
                ScoringFinish := Pilots[i].Leg[j].finish;
                //! Debug output
                Pilots[i].Warning := Pilots[i].Warning + #10 + IntToStr(j+1) + '. leg sector not reached';
              end;
            end;
          end;
        end;
      end;
      //TODO In case of control points, add length to PilotDis
      //PilotDis := PilotDis+something.
    end
    else
    begin
      // Less than 1 leg in Pilots[i].Leg
      //TODO Do we need to handle this case?
      PilotDis := 0;
    end;

    // If pilot has missed a radius, ScoringFinish was already set to the correct time. If not, set ScoringFinish to Pilots[i].finish
    if TPRounded Then
      ScoringFinish := Pilots[i].finish;

    // Assign ScoringFinish to a temporary variable, to be used later in power consumption
    Pilots[i].td2 := ScoringFinish;
    
    //! Debug output
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'End of scoring = ' + FormatFloat('0',ScoringFinish);
    if TPRounded Then
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'Task completed: True'
    else
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'Task completed: False';
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'PilotDis = ' + FormatFloat('0',PilotDis);

    // Set values for output
    Pilots[i].sstart := Task.NoStartBeforeTime;
    Pilots[i].sdis := PilotDis;
    if not TPRounded Then
    begin
      Pilots[i].sfinish := -1;
      Pilots[i].sspeed := 0;
    end
    else
    begin
      Pilots[i].sfinish := Pilots[i].finish;
      if Pilots[i].finish > 0 then
        Pilots[i].sspeed := PilotDis / (Pilots[i].finish - Task.NoStartBeforeTime);
    end;
  end;

  // Energy Consumption by pilot on task
  for i:=0 to GetArrayLength(Pilots)-1 do
  begin
    PilotEnergyConsumption := 0;
  	PilotEngineTime := 0;
    ScoringFinish := Pilots[i].td2;

    // Calculate Power consumption for a particular pilot
    for j := 0 to GetArrayLength(Pilots[i].Fixes)-1 do
    begin
      if (Pilots[i].Fixes[j].Tsec > Pilots[i].start) and (Pilots[i].Fixes[j].Tsec < ScoringFinish) Then
      begin
        // If pilot has Cur and Vol
        if Pilots[i].HasCur then
        begin
          if not Pilots[i].HasVol Then
            Pilots[i].Fixes[j].Vol := RefVoltage;
          if (Pilots[i].Fixes[j].Cur > 0) and (Pilots[i].Fixes[j].Vol > 0) then
          begin
            CurrentPower := Pilots[i].Fixes[j].Cur * Pilots[i].Fixes[j].Vol;
            If CurrentPower > PowerTreshold then
            begin
              PilotEngineTime := PilotEngineTime + Pilots[i].Fixes[j+1].Tsec - Pilots[i].Fixes[j].Tsec;
              // Pilots[i].Warning := Pilots[i].Warning + IntToStr(Round(Pilots[i].Fixes[j].Cur))+ ' * ' + IntToStr(Round(Pilots[i].Fixes[j].Vol)) + ' * ' + IntToStr(Pilots[i].Fixes[j+1].Tsec - Pilots[i].Fixes[j].Tsec) + #10;
              PilotEnergyConsumption := PilotEnergyConsumption + CurrentPower * (Pilots[i].Fixes[j+1].Tsec - Pilots[i].Fixes[j].Tsec) / 3600;
              Pilots[i].td1 := PilotEnergyConsumption;
            end;
          end;
        end
        else
        begin
          If Pilots[i].Fixes[j].EngineOn Then
          begin
            CurrentPower := RefPower;
            PilotEngineTime := PilotEngineTime + Pilots[i].Fixes[j+1].Tsec - Pilots[i].Fixes[j].Tsec;
            // Pilots[i].Warning := Pilots[i].Warning + IntToStr(Round(Pilots[i].Fixes[j].Cur))+ ' * ' + IntToStr(Round(Pilots[i].Fixes[j].Vol)) + ' * ' + IntToStr(Pilots[i].Fixes[j+1].Tsec - Pilots[i].Fixes[j].Tsec) + #10;
            PilotEnergyConsumption := PilotEnergyConsumption + CurrentPower * (Pilots[i].Fixes[j+1].Tsec - Pilots[i].Fixes[j].Tsec) / 3600;
            Pilots[i].td1 := PilotEnergyConsumption;
          end;
        end;
      end;
    end;


    //! Debug output
    if Pilots[i].HasCur Then
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasCur = 1'
    else
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasCur = 0';
    if Pilots[i].HasVol Then 
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasVol = 1'
    else
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasVol = 0';
    if Pilots[i].HasEnl Then 
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasEnl = 1'
    else
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasEnl = 0';
    if Pilots[i].HasMop Then 
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasMop = 1'
    else
      Pilots[i].Warning := Pilots[i].Warning + #10 + 'HasMop = 0';
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'EngineTime = ' + IntToStr(Round(PilotEngineTime)) + ' s';
    Pilots[i].Warning := Pilots[i].Warning + #10 + 'PowerConsumption = ' + IntToStr(Round(PilotEnergyConsumption)) + ' Wh';
    if PilotEnergyConsumption > FreeAllowance then
      Pilots[i].Warning := Pilots[i].Warning + #10 
        + 'Engine Penalty = ' + IntToStr(Round(PilotEnergyConsumption-FreeAllowance)) + ' Wh = ' 
        + FormatFloat('0.00',((PilotEnergyConsumption - FreeAllowance) * EnginePenaltyPerSec / 60)) + ' minutes';
  end;

  // Find the fastest and slowest finisher - T0 and Tm. Engine penalty included
  T0 := 10000000;
  Tm := 0;
  for i:=0 to GetArrayLength(Pilots)-1 do
  begin
    If not Pilots[i].isHC Then
    begin
      // Find the lowest task time
      EnginePenalty := 0;
      PilotEnergyConsumption := Pilots[i].td1;
      // Engine penalty
      if PilotEnergyConsumption > FreeAllowance then
      begin
        EnginePenalty := (PilotEnergyConsumption - FreeAllowance) * EnginePenaltyPerSec / 60; // Penalty in minutes
        Pilots[i].Points := Pilots[i].Points - EnginePenalty;
      end;
      T := Pilots[i].finish + EnginePenalty - Task.NoStartBeforeTime;
      If (T < T0) and (Pilots[i].finish > 0) Then
      begin
        T0 := T;
        minIdx := i;
      end;

      // Find the slowest finisher
      if T > Tm Then
      begin
        Tm := T;
      end;
    end;
  end;

  //! Debug output
  Info4 := 'Fastest (T0) = ' + FormatFloat('0',T0);
  Info4 := Info4 + '; Slowest (Tm) = ' + FormatFloat('0',Tm);

  
  // ELAPSED TIME SCORING
  for i:=0 to GetArrayLength(Pilots)-1 do 
  begin
    PilotEnergyConsumption := Pilots[i].td1;
    if Pilots[i].finish > 0 then
    begin
      Pilots[i].Points := ( T0 - (Pilots[i].finish - Task.NoStartBeforeTime) )/60;
      // Engine penalty
      if PilotEnergyConsumption > FreeAllowance then
      begin
        EnginePenalty := (PilotEnergyConsumption - FreeAllowance) * EnginePenaltyPerSec / 60; // Penalty in minutes
        Pilots[i].Points := Pilots[i].Points - EnginePenalty;
      end;
    end
    else
    begin
      // Outlanders get 1.2 (Fa) x the fastest finisher
        Pilots[i].Points := ( T0 - T0*Fa )/60;
    end;

    //Worst score a pilot can get is 1.2 (Fa) x the fastest finisher
    if Pilots[i].Points < (( T0 - T0*Fa )/60) Then
      Pilots[i].Points := ( T0 - T0*Fa )/60;
      
    Pilots[i].Points := Round((Pilots[i].Points - Pilots[i].Penalty/60)*100)/100; // Expected penalty is in seconds
  end;
    


  // Info fields, also presented on the Score Sheets
  Info1 := 'Elapsed time race with distance handicapping.';
  Info1 := Info1 + 'Results are in minutes behind leader'; 
  // for i := 0 to GetArrayLength(Pilots[i]) do
  // begin

  // end;
  // Info2 := '';
end.
