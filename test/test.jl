const datafile = "test.csv"
const nloops = 10

function testfn(f::Function, s::String)
    println("\t$(s)...")
    ret = f()
    println("\t\tresult: $(ret)")

    t = @elapsed for i in 1:nloops f(); end
    println("\t\ttime: $(t/nloops)")
end

f_df() = pmapreduce(x->nrow(x), +, Blocks(File(datafile)) |> filter_file_io |> filter_io_recordio |> (x)->filter_recordio_dataframe(x; header=false))
a_a1() = pmapreduce(x->sum(2*x), +, Blocks([1:10000000], filter_none, 1, nworkers()))
a_a2() = pmapreduce(x->sum(2*x), +, Blocks(reshape([1:1000],10,10,10), filter_none, [1,2]))
f_ios() = pmapreduce(x->length(x), +, Blocks(File(datafile)) |> filter_file_io |> filter_io_recordio |> filter_recordio_lines)

function procaff()
    b = Blocks(File(datafile)) |> filter_file_io |> filter_io_recordio |> filter_recordio_lines
    # create random affinities
    wrkrids = workers()
    nw = length(wrkrids)
    b.affinity = map(x->randsample(wrkrids, min(3,nw)), 1:nw)
    pmapreduce(x->length(x), +, b)
end

function load_pkgs()
    println("loading packages...")
    @everywhere using Block
    @everywhere using Base.FS
    @everywhere using DataFrames
end

function do_all_tests()
    println("running tests...")
    testfn(f_df, "file->dataframe")
    testfn(a_a1, "array->array")
    testfn(a_a2, "array->array")
    testfn(f_ios, "file->iostream")
    testfn(procaff, "map processor affinity")
end

load_pkgs()
do_all_tests()

println("adding 3 more processors...")
addprocs(3)
println("\tnprocs: $(nprocs())")
load_pkgs()
do_all_tests()

