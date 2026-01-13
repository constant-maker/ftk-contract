import characterQuestions from './characterQuestions.json';
import items from './items.json';
import itemRecipes from './itemRecipes.json';
import map from './map.json';
import types from './types.json';
import welcomeConfig from './welcomeConfig.json';
import quests from './quests.json';
import skills from './skills.json';
import monsters from './monsters.json';
import monsterLocations from './monsterLocations.json';
import monsterLocationsBoss from './monsterLocationsBoss.json';
import achievements from './achievements.json';
import itemExchanges from './itemExchanges.json';

const dataConfig = {
  ...types,
  ...characterQuestions,
  ...items,
  ...itemRecipes,
  ...map,
  ...welcomeConfig,
  ...quests,
  ...skills,
  ...monsters,
  ...monsterLocations,
  ...monsterLocationsBoss,
  ...achievements,
  ...itemExchanges,
};

export default dataConfig;
