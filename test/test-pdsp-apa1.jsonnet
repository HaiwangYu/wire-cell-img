// This is a test jsonnet.  Some parts are a hack so don't look for
// pristine Jsonnet practices/examples.

// Set to true for DepoSplat fast sim+sigproc, else use full sim/sigproc
local fast_splat = true;

// It sets up PDSP but with only one APA to make test jobs faster.

local wc = import "wirecell.jsonnet";
local g = import "pgraph.jsonnet";
local f = import 'pgrapher/experiment/pdsp/funcs.jsonnet';
local io = import "pgrapher/common/fileio.jsonnet";


local params6 = import "pgrapher/experiment/pdsp/simparams.jsonnet";

// APA 1 is on positive global-X side of pD SP
local apa_index = 1;

// for now, we focus on just one face.  The 0 face is toward the
// positive-X direction.
local face = 1;

local frame_tags = if fast_splat then [] else ["wiener%d"%apa_index, "gauss%d"%apa_index];
local slice_tag = if fast_splat then "" else "gauss%d"%apa_index;

// Hack to strip out just one APA.
//
// BEWARE: you must manually make bounds match the chosen apa_index
local params = params6 {
    det : super.det {
        bounds : {
            tail: wc.point(0.0, 0.0, 0.0, wc.m),
            head: wc.point(4.0, 2.0, 7.0, wc.m),
        },
        volumes: [ super.volumes[apa_index] ]
    }
};

local tools_maker = import "pgrapher/common/tools.jsonnet";
local sim_maker = import "pgrapher/experiment/pdsp/sim.jsonnet";

local tools = tools_maker(params);
local anode = tools.anodes[0];

local sim = sim_maker(params, tools);


// bb:   (2.54 7.61 0.3358)cm
// --> (357.985 606 230.352)cm

// sensitive volume bb for pdsp apa 1 face 1 in mm:
// [(25.4 76.1 3.358) --> (3579.85 6060 2303.52)]
local blip = {
    // put stuff near V and W zero wires
    tail: wc.point(200.0, 3000.0, 1000.0, wc.mm),
    head: wc.point(210.0, 3000.0, 1000.0, wc.mm),
};
local stubby = {
    tail: wc.point(100.0, 100.0, 130.0, wc.cm),
    head: wc.point(120.0,  90.0, 140.0, wc.cm),
};
local cross = {
    tail: wc.point(100.0, 100.0, 140.0, wc.cm),
    head: wc.point(120.0,  90.0, 130.0, wc.cm),
};
local longer = {
    tail: wc.point(100.0, 100.0, 130.0, wc.cm),
    head: wc.point(150.0, 270.0, 100.0, wc.cm),
};
local tracklist = [
    // {
    //     time: 0*wc.us,
    //     charge: -5000,
    //     ray: blip,
    // },
    {
        time: 0*wc.us,
        charge: -5000,
        ray: stubby,
    },
    {
        time: 0*wc.us,
        charge: -5000,
        ray: cross,
    },
    // {
    //     time: 0*wc.us,
    //     charge: -5000,
    //     ray: longer,
    // },
    // {
    //     time: 20*wc.us,
    //     charge: -5000,
    //     ray: stubby,
    // },
];

local output = "test-pdsp.npz";

local depos = sim.tracks(tracklist);
local deposio = io.numpy.depos(output);
local drifter = sim.drifter;

// fast sim+sp
local deposplat = sim.make_ductor('splat', anode, tools.pirs[0], 'DepoSplat');

// full sim
local bagger = sim.make_bagger();
local simsn = sim.signal_pipelines[0]; // relative index over all anodes

// signal processing
local sp_maker = import 'pgrapher/experiment/pdsp/sp.jsonnet';
local sp = sp_maker(params, tools, { sparse: true } );
local sigproc = sp.make_sigproc(anode, apa_index);

local frameio = io.numpy.frames(output, tags=frame_tags);

local slices = g.pnode({
    type: "SumSlices",
    data: {
        tag: slice_tag,
        tick_span: 4,
        anode: wc.tn(anode),
    },
}, nin=1, nout=1, uses=[anode]);

local tiling = g.pnode({
    type: "GridTiling",
    data: {
        anode: wc.tn(anode),
        face: face,
    }
}, nin=1, nout=1, uses=[anode]);

local sink = g.pnode({
    type: "JsonBlobSetSink",
    data: {
        anode: wc.tn(anode),
        face: face,
        filename: "test-pdsp-%02d.json",
    },
}, nin=1, nout=0, uses=[anode]);


local graph = g.pipeline([depos, deposio, drifter,
                          deposplat,
                          //bagger, simsn, sigproc,
                          frameio, slices, tiling, sink]);

local cmdline = {
    type: "wire-cell",
    data: {
        plugins: ["WireCellGen", "WireCellPgraph", "WireCellSio", "WireCellSigProc", "WireCellImg"],
        apps: ["Pgrapher"]
    },
};

local app = {
    type: "Pgrapher",
    data: {
        edges: g.edges(graph),
    },
};

[cmdline] + g.uses(graph) + [app]

