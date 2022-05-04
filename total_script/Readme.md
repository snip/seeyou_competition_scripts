## How to use Total script (optional)

The script for Total results is optional. It is blank by default. In the absence of a Total script, results are simply added together to create a total score for each competitor.

If that doesn't solve your problem, you can use the Total script to calculate Total results in a different way. Procedure is the same way as for daily scripts except that they are located in Edit > Competition Properties > Total Script.

### Available variables for Total script

Pilots = record

Total : Double; total points (default value is sum of DayPoints, not 0)

TotalString : String; if this is not empty, total points will be shown as the string defined in this value 

DayPts : array of Double; Points from each day as calculated in daily scripts

DayPtsString : array of String; Same functionality as TotalString
