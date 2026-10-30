--- The key hints along the bottom of the screen (the game's instructional buttons).
Hints = {}

local movie, shown = nil, nil

--- Draws this frame's hints, a list of { control, label }. The list is set
--- up again only when a different one is passed.
function Hints.draw(list)
    movie = movie or RequestScaleformMovie('instructional_buttons')
    if not HasScaleformMovieLoaded(movie) then return end
    if shown ~= list then
        BeginScaleformMovieMethod(movie, 'CLEAR_ALL')
        EndScaleformMovieMethod()
        for i, hint in ipairs(list) do
            BeginScaleformMovieMethod(movie, 'SET_DATA_SLOT')
            ScaleformMovieMethodAddParamInt(i - 1)
            ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, hint[1], true))
            BeginTextCommandScaleformString('STRING')
            AddTextComponentScaleform(hint[2])
            EndTextCommandScaleformString()
            EndScaleformMovieMethod()
        end
        BeginScaleformMovieMethod(movie, 'DRAW_INSTRUCTIONAL_BUTTONS')
        EndScaleformMovieMethod()
        shown = list
    end
    DrawScaleformMovieFullscreen(movie, 255, 255, 255, 255, 0)
end
