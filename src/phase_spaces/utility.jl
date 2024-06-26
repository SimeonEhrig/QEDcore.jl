# recursion termination: base case
@inline _assemble_tuple_type(::Tuple{}, ::QEDbase.ParticleDirection, ::Type) = ()

# function assembling the correct type information for the tuple of ParticleStatefuls in a phasespace point constructed from momenta
@inline function _assemble_tuple_type(
    particle_types::Tuple{SPECIES_T,Vararg{QEDbase.AbstractParticleType}},
    dir::DIR_T,
    ELTYPE::Type,
) where {SPECIES_T<:QEDbase.AbstractParticleType,DIR_T<:QEDbase.ParticleDirection}
    return (
        ParticleStateful{DIR_T,SPECIES_T,ELTYPE},
        _assemble_tuple_type(particle_types[2:end], dir, ELTYPE)...,
    )
end

# recursion termination: success
@inline _recursive_type_check(::Tuple{}, ::Tuple{}, ::QEDbase.ParticleDirection) = nothing

# recursion termination: overload for unequal number of particles
@inline function _recursive_type_check(
    ::Tuple{Vararg{ParticleStateful,N}},
    ::Tuple{Vararg{QEDbase.AbstractParticleType,M}},
    dir::QEDbase.ParticleDirection,
) where {N,M}
    throw(
        QEDbase.InvalidInputError(
            "expected $(M) $(dir) particles for the process but got $(N)"
        ),
    )
    return nothing
end

# recursion termination: overload for invalid types
@inline function _recursive_type_check(
    ::Tuple{ParticleStateful{DIR_IN_T,SPECIES_IN_T},Vararg{ParticleStateful,N}},
    ::Tuple{SPECIES_T,Vararg{QEDbase.AbstractParticleType,N}},
    dir::DIR_T,
) where {
    N,
    DIR_IN_T<:QEDbase.ParticleDirection,
    DIR_T<:QEDbase.ParticleDirection,
    SPECIES_IN_T<:QEDbase.AbstractParticleType,
    SPECIES_T<:QEDbase.AbstractParticleType,
}
    throw(
        QEDbase.InvalidInputError(
            "expected $(dir) $(SPECIES_T()) but got $(DIR_IN_T()) $(SPECIES_IN_T())"
        ),
    )
    return nothing
end

@inline function _recursive_type_check(
    t::Tuple{ParticleStateful{DIR_T,SPECIES_T},Vararg{ParticleStateful,N}},
    p::Tuple{SPECIES_T,Vararg{QEDbase.AbstractParticleType,N}},
    dir::DIR_T,
) where {N,DIR_T<:QEDbase.ParticleDirection,SPECIES_T<:QEDbase.AbstractParticleType}
    return _recursive_type_check(t[2:end], p[2:end], dir)
end

@inline function _check_psp(
    in_proc::P_IN_Ts, out_proc::P_OUT_Ts, in_p::IN_Ts, out_p::OUT_Ts
) where {
    P_IN_Ts<:Tuple{Vararg{QEDbase.AbstractParticleType}},
    P_OUT_Ts<:Tuple{Vararg{QEDbase.AbstractParticleType}},
    IN_Ts<:Tuple{Vararg{ParticleStateful}},
    OUT_Ts<:Tuple{},
}
    # specific overload for InPhaseSpacePoint
    _recursive_type_check(in_p, in_proc, QEDbase.Incoming())

    return typeof(in_p[1].mom)
end

@inline function _check_psp(
    in_proc::P_IN_Ts, out_proc::P_OUT_Ts, in_p::IN_Ts, out_p::OUT_Ts
) where {
    P_IN_Ts<:Tuple{Vararg{QEDbase.AbstractParticleType}},
    P_OUT_Ts<:Tuple{Vararg{QEDbase.AbstractParticleType}},
    IN_Ts<:Tuple{},
    OUT_Ts<:Tuple{Vararg{ParticleStateful}},
}
    # specific overload for OutPhaseSpacePoint
    _recursive_type_check(out_p, out_proc, QEDbase.Outgoing())

    return typeof(out_p[1].mom)
end

@inline function _check_psp(
    in_proc::P_IN_Ts, out_proc::P_OUT_Ts, in_p::IN_Ts, out_p::OUT_Ts
) where {
    P_IN_Ts<:Tuple{Vararg{QEDbase.AbstractParticleType}},
    P_OUT_Ts<:Tuple{Vararg{QEDbase.AbstractParticleType}},
    IN_Ts<:Tuple{Vararg{ParticleStateful}},
    OUT_Ts<:Tuple{Vararg{ParticleStateful}},
}
    # in_proc/out_proc contain only species types
    # in_p/out_p contain full ParticleStateful types

    _recursive_type_check(in_p, in_proc, QEDbase.Incoming())
    _recursive_type_check(out_p, out_proc, QEDbase.Outgoing())

    return typeof(out_p[1].mom)
end

"""
    _momentum_type(psp::PhaseSpacePoint)
    _momentum_type(type::Type{PhaseSpacePoint})

Returns the element type of the [`PhaseSpacePoint`](@ref) object or type, e.g. `SFourMomentum`.

TODO: Turn this back into a `jldoctest` once refactoring is done.
```Julia
julia> using QEDcore; using QEDprocesses

julia> psp = PhaseSpacePoint(Compton(), PerturbativeQED(), PhasespaceDefinition(SphericalCoordinateSystem(), ElectronRestFrame()), Tuple(rand(SFourMomentum) for _ in 1:2), Tuple(rand(SFourMomentum) for _ in 1:2));

julia> _momentum_type(psp)
SFourMomentum

julia> _momentum_type(typeof(psp))
SFourMomentum
```
"""
@inline function _momentum_type(
    ::Type{T}
) where {P,M,D,I,O,E,T<:PhaseSpacePoint{P,M,D,I,O,E}}
    return E
end

@inline _momentum_type(::T) where {T<:PhaseSpacePoint} = _momentum_type(T)

# convenience function building a type stable tuple of ParticleStatefuls from the given process, momenta, and direction
function _build_particle_statefuls(
    proc::QEDbase.AbstractProcessDefinition,
    moms::NTuple{N,ELEMENT},
    dir::QEDbase.ParticleDirection,
) where {N,ELEMENT<:QEDbase.AbstractFourMomentum}
    N == QEDbase.number_particles(proc, dir) || throw(
        QEDbase.InvalidInputError(
            "expected $(QEDbase.number_particles(proc, dir)) $(dir) particles for the process but got $(N)",
        ),
    )
    res = Tuple{_assemble_tuple_type(QEDbase.particles(proc, dir), dir, ELEMENT)...}(
        ParticleStateful(dir, particle, mom) for
        (particle, mom) in zip(QEDbase.particles(proc, dir), moms)
    )

    return res
end