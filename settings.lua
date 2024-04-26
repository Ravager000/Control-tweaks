
data:extend {
    {
        type = 'bool-setting',
        name = 'picker-auto-manual-train',
        setting_type = 'runtime-per-user',
        default_value = true,
        order = 'picker-e[automatic-trains]-a'
    },
    {
        type = 'bool-setting',
        name = 'picker-manual-train-keys',
        setting_type = 'runtime-per-user',
        default_value = true,
        order = '[startup]-e-[automatic-trains]-b'
    }
}

data:extend {
    {
        type = 'bool-setting',
        name = 'picker-trash-cheat',
        setting_type = 'runtime-per-user',
        default_value = true,
        order = '[zapper]-d'
    },
    {
        type = 'bool-setting',
        name = 'picker-trash-planners',
        setting_type = 'runtime-per-user',
        default_value = false,
        order = '[zapper]-e'
    },
    {
        type = 'bool-setting',
        name = 'picker-item-zapper-all',
        setting_type = 'runtime-per-user',
        default_value = false,
        order = '[zapper]-y'
    }
}