import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:smashlike/game/assets/fighters_assets.dart';
import 'package:smashlike/game/game_assets.dart';
import 'package:smashlike/game/multiplayer/multiplayer.dart';
import 'package:smashlike/menus/endscreen.dart';
import 'package:smashlike/smash_engine/asset.dart';
import 'package:smashlike/smash_engine/smash_engine.dart';

// TODO
// bluetooth (sync)
// init/reset method for multi before use
// isolate multiplayer
// Check mulitplayer start fail
// check blocking with attacks
// adjust animations timing and other parameters (hitboxes, hurtboxes, ...)
// restructure menus & clean code
// private variables and functions
// santas fighter color

class SmashLikeLogic extends GameLogic {
  Multiplayer multiplayer = Multiplayer();
  bool useMultiplayer = true;
  
  int counter = 0;
  int max_counter = 5;

  SmashLikeLogic({this.useMultiplayer});

  @override
  Future<int> update(Queue<String> inputs, GameAssets gameAssets) async {
    // extract the assets
    SmashLikeAssets assets = gameAssets;
    Fighter player = assets.player;
    Fighter opponent = assets.opponent;
    List<Fireball> fireballs = assets.fireballs;
  
    // player inputs
    String playerInput = '';
    if(inputs.length > 0) {
      playerInput = inputs.removeFirst(); // one input per frame
      switch(playerInput) {
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
      }
    }

    if(useMultiplayer) {
      // check connection failure
      if((await multiplayer.isConnected) == false) {

        endGameScreen = EndScreen(status: EndScreen.CONNECTION_LOST);
        return GameLogic.FINISHED;
      }
      // synchronize fighters
      await multiplayerUpdate(playerInput, player, opponent);
    }

    // basic attacks
    if(checkHurtBasic(player, opponent) && (opponent.damage < 100)) {
      opponent.damage += 0.1;
      opponent.hit();
    }
    if(checkHurtBasic(opponent, player) && (player.damage < 100)) {
      player.damage += 0.1;
      player.hit();
    }
    
    // smash attacks
    bool ejectOpponent = checkHurtSmash(player, opponent);
    bool ejectPlayer = checkHurtSmash(opponent, player);
    if(ejectPlayer){
      player.eject();
      ejectFighter(player, opponent.orientation, 3, 8);
    }
    if(ejectOpponent){
      opponent.eject();
      ejectFighter(opponent, player.orientation, 3, 8);
    }

    // remove useless fireballs
    fireballs.removeWhere((fireball) => fireball.velX == 0);
    // check fireballs ready to be launched
    if(player.fireballReady())
      fireballs.add(player.launchFireball());
    if(opponent.fireballReady())
      fireballs.add(opponent.launchFireball());
    // check fireballs hits
    for(Fireball fireball in fireballs) {
      if(checkHurtFireball(player, fireball)) {
        player.hit();
        if(player.damage < 100) {
          player.damage += 5;
        }
        fireball.velX = 0;
        continue;
      }
      if(checkHurtFireball(opponent, fireball)) {
        opponent.hit();
        if(opponent.damage < 100) {
          opponent.damage += 5;
        }
        fireball.velX = 0;
      }
    }

    if(outOfLimits(player)) {
      player.posX = player.respawnPosX;
      player.posY = player.respawnPosY;
      player.velX = 0;
      player.velY = 0;
      player.damage = 0;
      player.lifes--;
      if(player.lifes == 0) {
        if(useMultiplayer)
          multiplayer.disconnect();
        endGameScreen = EndScreen(status: EndScreen.DEFEAT);
        return GameLogic.FINISHED;
      }
    }
    if(outOfLimits(opponent)) {
      opponent.posX = opponent.respawnPosX;
      opponent.posY = opponent.respawnPosY;
      opponent.velX = 0;
      opponent.velY = 0;
      opponent.damage = 0;
      opponent.lifes--;
      if(opponent.lifes == 0) {
        if(useMultiplayer)
          multiplayer.disconnect();
        endGameScreen = EndScreen(status: EndScreen.VICTORY);
        return GameLogic.FINISHED;
      }
    }
    
    return GameLogic.ON_GOING;
  }

  bool outOfLimits(Fighter fighter) {
    if(fighter.posX < -10 || fighter.posX > 110 || fighter.posY < -8)
      return true;
    return false;
  }

  bool checkHurtBasic(Fighter att, Fighter def) {
    return (max(att.hurtBasicLeft, def.hitboxLeft) 
    < min(att.hurtBasicRight, def.hitboxRight) 
    && max(att.hurtBasicBottom, def.hitboxBottom) 
    < min(att.hurtBasicTop, def.hitboxTop));
  }

  bool checkHurtSmash(Fighter att, Fighter def) {
    return (max(att.hurtSmashLeft, def.hitboxLeft) 
    < min(att.hurtSmashRight, def.hitboxRight) 
    && max(att.hurtSmashBottom, def.hitboxBottom) 
    < min(att.hurtSmashTop, def.hitboxTop));
  }

  bool checkHurtFireball(Fighter fighter, Fireball fireball) {
    return((fireball.id != fighter.id)
    && (max(fighter.hitboxLeft, fireball.hitboxLeft) 
    < min(fighter.hitboxRight, fireball.hitboxRight) 
    && max(fighter.hitboxBottom, fireball.hitboxBottom) 
    < min(fighter.hitboxTop, fireball.hitboxTop)));
  }

  void ejectFighter(Fighter fighter, int orientation, 
                    double intensityX, double intensityY) {
    if(orientation == Fighter.LEFT)
      fighter.velX -= intensityX*(fighter.damage/100);
    else
      fighter.velX += intensityX*(fighter.damage/100);
    fighter.velY += intensityY*(fighter.damage/100);
  }

  Future multiplayerUpdate(String playerInput, Fighter player, 
                           Fighter opponent) async {
    // player
    int pPosX = player.posX.round();
    int pPosY = player.posY.round();
    switch(playerInput) {
      case "press_left_start":
        multiplayer.send(List<double>.from([Multiplayer.LEFT_START, pPosX, pPosY]));
      break;

      case "press_left_end":
        multiplayer.send(List<double>.from([Multiplayer.LEFT_END, pPosX, pPosY]));
      break;

      case "press_right_start":
        multiplayer.send(List<double>.from([Multiplayer.RIGHT_START, pPosX, pPosY]));
      break;

      case "press_right_end":
        multiplayer.send(List<double>.from([Multiplayer.RIGHT_END, pPosX, pPosY]));
      break;

      case "press_up":
        multiplayer.send(List<double>.from([Multiplayer.UP, pPosX, pPosY]));
      break;

      case "press_a":
        multiplayer.send(List<double>.from([Multiplayer.A, pPosX, pPosY]));
      break;

      case "long_press_a":
        multiplayer.send(List<double>.from([Multiplayer.LONG_A, pPosX, pPosY]));
      break;
        
      case "press_b_start":
        multiplayer.send(List<double>.from([Multiplayer.B_START, pPosX, pPosY]));
      break;

      case "press_b_end":
        multiplayer.send(List<double>.from([Multiplayer.B_END, pPosX, pPosY]));
      break;
        
      case "press_fireball":
        multiplayer.send(List<double>.from([Multiplayer.FIREBALL, pPosX, pPosY]));
      break;

      default:
        multiplayer.send(List<double>.from([Multiplayer.NONE, pPosX, pPosY]));
      break;
    }

    // opponent
    List<double> values = await multiplayer.receive();
    if(values.isEmpty)
      return;
    opponent.posX = values[1].toDouble();
    opponent.posY = values[2].toDouble();
    switch(values[0].round()) {
      case Multiplayer.LEFT_START:
        opponent.move(Fighter.LEFT);
      break;

      case Multiplayer.LEFT_END:
        opponent.stopMove();
      break;

      case Multiplayer.RIGHT_START:
        opponent.move(Fighter.RIGHT);
      break;

      case Multiplayer.RIGHT_END:
        opponent.stopMove();
      break;

      case Multiplayer.UP:
        opponent.jump(); 
      break;

      case Multiplayer.A:
        opponent.basicAttack();
      break;

      case Multiplayer.LONG_A:
        opponent.smashAttack();
      break;
        
      case Multiplayer.B_START:
        opponent.block();
      break;

      case Multiplayer.B_END:
        opponent.stopBlock();
      break;
        
      case Multiplayer.FIREBALL:
        opponent.fireball();
      break;
    }
  }
}
