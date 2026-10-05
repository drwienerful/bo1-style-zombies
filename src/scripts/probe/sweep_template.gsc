// bo1sz builtin sweep: compile-only check for ONE builtin (__NAME__).
// tools/install.ps1 -Batch Sweep stamps one copy per line of sweep_candidates.txt.
// The call sits in a branch that never runs; only Plutonium's compiler sees it.
// Result is read from main\console.log: "Script ... loaded successfully" = known,
// "unknown function @ ...bo1sz_sweep_..." = not callable by name from our source.

init()
{
	if ( getDvar( "bo1sz_sweep_never" ) == "this dvar is never set" )
	{
		e = GetPlayers()[ 0 ];
		__CALL__
	}
}
