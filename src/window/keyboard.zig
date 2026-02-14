// Representation of a keyboard key
pub const Key = union(enum) {
    // Function keys
    function: u4, // F1-F12 (you might want u5 for F13-F24 on some keyboards)

    // Alphanumeric
    character: u8, // A-Z, 0-9

    // Special characters (important for non-US keyboards!)
    semicolon: void, // ;
    equals: void, // =
    comma: void, // ,
    minus: void, // -
    period: void, // .
    slash: void, // /
    grave_accent: void, // ` ~
    left_bracket: void, // [
    backslash: void, // \
    right_bracket: void, // ]
    apostrophe: void, // '

    // Navigation
    escape: void,
    space: void,
    enter: void,
    tab: void,
    backspace: void,
    delete: void,
    insert: void,
    home: void,
    end: void,
    page_up: void,
    page_down: void,
    arrow: enum { up, down, left, right },

    // Modifiers (you have these as separate, but also good to detect as keys)
    left_shift: void,
    right_shift: void,
    left_control: void,
    right_control: void,
    left_alt: void,
    right_alt: void,
    left_super: void, // (Windows key / Command)
    right_super: void,

    // Lock keys
    caps_lock: void,
    scroll_lock: void,
    num_lock: void,

    // System keys
    print_screen: void,
    pause: void,
    menu: void, // (context menu key)

    // Numpad
    numpad: enum {
        zero,
        one,
        two,
        three,
        four,
        five,
        six,
        seven,
        eight,
        nine,
        add,
        subtract,
        multiply,
        divide,
        decimal,
        enter,
        // Tab, backspace, delete are already there
    },

    // Media keys
    media: enum {
        play_pause,
        stop,
        next_track,
        previous_track,
        mute,
        volume_up,
        volume_down,
    },

    // Browser keys
    browser: enum {
        back,
        forward,
        refresh,
        stop,
        search,
        favorites,
        home,
    },

    // App launch keys
    app: enum {
        calculator,
        mail,
        media_player,
        my_computer,
    },

    // International keys (for non-US keyboards)
    world_1: void,
    world_2: void,
    // Fallback
    unknown: u32, // Store the raw VK code for unmapped keys
};

/// Represents a key modifier that can be used to modify the behavior of a key press.
pub const KeyModifier = enum {
    shift,
    control,
    alt,
    super,
};
