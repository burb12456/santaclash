import 'dart:collection';
import 'package:smashlike/game/assets/fighters_assets.dart';
import 'package:smashlike/game/game_assets.dart';
import 'package:smashlike/smash_engine/asset.dart';
import 'package:smashlike/smash_engine/smash_engine.dart';

// TODO
// add opponent
// update inputs buttons
// further improve animation and action system (quicker blocking)
// adjust animations timing
// bluetooth or AI
// private variables and functions

class SmashLikeLogic extends GameLogic {
  @override
  void update(Queue<String> inputs, GameAssets gameAssets) {
    SmashLikeAssets assets = gameAssets;
    Fighter player = assets.player;

    // fireballs
    assets.fireballs.removeWhere((fireball) => fireball.velX == 0);
    if(player.fireballReady())
      assets.fireballs.add(player.launchFireball());

    // inputs
    while(inputs.length > 0) {
      switch(inputs.removeFirst()) {
        case "press_left_start":
          player.move(Fighter.LEFT);
        break;

        case "press_left_end":
          player.stopMove();
        break;

        case "press_right_start":
          player.move(Fighter.RIGHT);
        break;

        case "press_right_end":
          player.stopMove();
        break;

        case "press_up":
          player.jump(); 
        break;

        case "press_a":
          player.basicAttack();
        break;

        case "long_press_a":
          player.smashAttack();
        break;
        
        case "press_b_start":
          player.block();
        break;

        case "press_b_end":
          player.stopBlock();
        break;
        
        case "press_fireball":
          player.fireball();
        break;

        default:
          break;
      }
    }
  }
}