class ST_UTChunkInfo extends Info;

var Actor Victim[8];
var int HitCount;
var int ChunkCount;

var IGPlus_WeaponImplementation WImp;

function AddChunk(ST_UTChunk Chunk)
{
	local bbPlayer bbP;

	bbP = bbPlayer(Owner);

	if (Chunk == None)
		return;				// If it for some reason failed to spawn.
	Chunk.Chunkie = Self;
	Chunk.ChunkIndex = ChunkCount++;
	Chunk.LifeSpan = WImp.WeaponSettings.FlakChunkLifespan;

	// Apply ping compensation for flak chunks if enabled
	if (bbP != none && WImp.WeaponSettings.FlakCompensatePing) {
		// Apply ping compensation simulation to each chunk
		WImp.SimulateProjectile(Chunk, bbP.PingAverage);
		Chunk.LifeSpan -= bbP.PingAverage*0.001*Level.TimeDilation;
	}
}

// The chunks have a lifespan of 2.9-3.1 seconds, so this is sufficient.
defaultproperties {
	LifeSpan=3.5
}
