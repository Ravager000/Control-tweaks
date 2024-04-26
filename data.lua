-- Picker Belt
data:extend { { type = 'custom-input', name = 'picker-reverse-belts', key_sequence = 'ALT + R' } }
-- Picker Veicule
local Data = require('__stdlib__/stdlib/data/data')

Data { type = 'custom-input', name = 'picker-toggle-train-control', key_sequence = 'J' }

Data { type = 'custom-input', name = 'picker-up-event', linked_game_control = 'move-up', key_sequence = '', localised_name = 'Manual Train up' }
Data { type = 'custom-input', name = 'picker-down-event', linked_game_control = 'move-down', key_sequence = '', localised_name = 'Manual Train down' }
Data { type = 'custom-input', name = 'picker-left-event', linked_game_control = 'move-left', key_sequence = '', localised_name = 'Manual Train left' }
Data { type = 'custom-input', name = 'picker-right-event', linked_game_control = 'move-right', key_sequence = '', localised_name = 'Manual Train right' }
--picker inventory
local Entity = require('__stdlib__/stdlib/data/entity')

local setup_animation = function(entity)
    for _, animation in pairs(entity.animations) do
        animation.scale = .5
    end
    for _, variation in pairs(entity.sound.variations) do
        variation.filename = '__base__/sound/fight/laser-1.ogg'
        variation.volume = .5
    end
end

Entity('explosion', 'explosion'):copy('drop-planner'):execute(setup_animation)

Entity {
    type = 'custom-input',
    name = 'picker-zapper',
    key_sequence = 'ALT + Z'
}
