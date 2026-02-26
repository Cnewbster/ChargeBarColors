# Charge Bar Colors

A World of Warcraft addon that allows you to customize the colors of charge bars for various class abilities.

## Features

- **Universal Support**: Works with ANY class that uses charge/resource bars
- **Per-Charge Coloring**: Set a different color for EACH individual charge (Charge 1, Charge 2, Charge 3, etc.)
- **Base UI Compatible**: Works seamlessly with WoW's default UI
- **WoW Color Wheel**: Uses WoW's built-in color picker for easy color selection
- **Automatic Detection**: Automatically detects your class and resource type
- **Multi-Class Support**: Configure colors for all resource types (Combo Points, Chi, Holy Power, Soul Shards, Runes, Essence, Whirlwind Stacks, etc.)
- **Easy-to-use Configuration UI**: Intuitive interface with individual color buttons for each charge
- **Enable/disable toggle**: Turn the addon on/off easily
- **Real-time Updates**: Colors update automatically when your charges change

## Installation

1. Copy the `ChargeBarColors` folder to your World of Warcraft `Interface/AddOns` directory:
   - **Windows**: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
   - **Mac**: `/Applications/World of Warcraft/_retail_/Interface/AddOns/`

2. Restart World of Warcraft or type `/reload` in-game

3. The addon will be available in your AddOns list at the character selection screen

## Usage

### Opening the Configuration Panel

Type one of these commands in-game:
- `/chargecolors`
- `/cbc`

### Configuring Colors

1. Open the configuration panel using the slash command (`/chargecolors` or `/cbc`)
2. Check/uncheck "Enable Charge Bar Colors" to toggle the addon on/off
3. Select the resource type you want to configure from the dropdown menu
4. Click on any "Charge X" color button to open WoW's color picker
5. Use the color wheel to select your desired color
6. Click OK to apply - changes are applied immediately to your charge bars
7. Each charge can have its own unique color!

**Example**: You can make Charge 1 red, Charge 2 orange, Charge 3 yellow, Charge 4 green, etc.

### Supported Resource Types

The addon automatically detects your class and applies the appropriate color. You can configure colors for:

- **Combo Points** (Rogue, Feral Druid)
- **Chi** (Monk)
- **Holy Power** (Paladin)
- **Soul Shards** (Warlock)
- **Runes** (Death Knight)
- **Essence** (Evoker)
- **Whirlwind Stacks** (Warrior with Improved Whirlwind talent)
- **Default**: Fallback color for any other resource types

The configuration panel will show your current class's resource type at the top, and you can customize colors for all resource types even if you're not currently playing that class.

## Technical Notes

This addon hooks into WoW's charge bar system and modifies the colors of various class-specific resource indicators. The implementation uses secure hooks to ensure compatibility with WoW's security model.

## Troubleshooting

- If colors don't apply, make sure the addon is enabled in the configuration panel
- Some charge bars may require you to be in combat or have the ability active to see changes
- If you encounter issues, try `/reload` to reload the UI

## Version

1.0.0 - Initial release

## Compatibility

- World of Warcraft Retail (Interface version 100105)
- Requires a compatible WoW client

## Shout Out

Thanks to Smallscales for helping me test almost everything I've done with the evoker side of this addon!
Also thanks to Sensei for his repo on his current resource manager for how to help use the Warrior WW buffs.
