"""
    create(; kwargs...)
    create(config::Config, args...; kwargs...)
    create(env::Environment; kwargs...)

Creates a new playground `Environment` including initializing its package directory and installing
any package in the REQUIRE file passed in.

# Optional Arguments
You can optionally pass in an `Environment` instance of a `Config` and args to build one.

# Keywords Arguments
* `julia::AbstractString` - a julia binary to use in this playground environment.
* `reqs_file::AbstractPath` - path to a REQUIRE file of packages to install in this environment.
"""
create(; kwargs...) = create(Environment(); kwargs...)
create(config::Config, args...; kwargs...) = create(Environment(config, args...); kwargs...)

function create(env::Environment; kwargs...)
    init(env)
    opts = Dict(kwargs)

    julia_exec = if haskey(opts, :julia) && !isempty(opts[:julia])
        join(env.config.bin, opts[:julia])
    else
        out = readchomp(`which julia`)
        debug(logger, out)
        debug(logger, Path(out))
        debug(logger, abs(Path(out)))
        abs(Path(readchomp(`which julia`)))
    end

    debug(logger, "$(julia(env)) -> $julia_exec")
    symlink(julia_exec, julia(env), exist_ok=true, overwrite=true)

    withenv(env) do
        Playground.log_output(`$(julia(env)) -e 'Pkg.init()'`)

        reqs_file = if haskey(opts, :reqs_file) && !isempty(opts[:reqs_file])
            opts[:reqs_file]
        else
            join(env.config.root, "REQUIRE")
        end

        if exists(reqs_file)
            info(logger, "Installing packages from REQUIRE file $reqs_file...")

            for v in readdir(pkg(env))
                copy(reqs_file, join(pkg(env), v, "REQUIRE"); exist_ok=true, overwrite=true)

                try
                    Playground.log_output(`$(julia(env)) -e 'Pkg.resolve()'`)
                catch
                    warn(logger, string(
                        "Failed to resolve requirements. ",
                        "Perhaps there is something wrong with your REQUIRE file."
                    ))
                end
            end
        end
    end
end
