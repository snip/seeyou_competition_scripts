Program eGlide_Total_results;
var i, j, minIdx : integer;
    min, PilotTotal, WinnersTotal : double;
begin

  // Find the lowest score
  min := -1000000;
  minIdx := -1;
  for i := 0 to GetArrayLength(Pilots)-1 do
  begin
    if Pilots[i].Total > min Then
	begin
	  min := Pilots[i].Total;
	  minIdx := i;
	end;
  end;
  
  for i := 0 to GetArrayLength(Pilots)-1 do
  begin
    Pilots[i].Total := Pilots[i].Total - min;
//    ShowMessage(Pilots[i].CompID + ' ' + IntToStr(Round(Pilots[i].Total)));
  end;
  
//  Pilots[minIdx].Total := WinnersTotal;
end.
