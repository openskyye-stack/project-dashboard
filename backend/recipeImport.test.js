import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import { jsonLdBlocks, findRecipe, isoMinutes, servings, numeric, instructions, text } from './recipeImport.js';

describe('ISO 8601 durations', () => {
  test('parses hours and minutes', () => {
    assert.equal(isoMinutes('PT30M'), 30);
    assert.equal(isoMinutes('PT1H15M'), 75);
    assert.equal(isoMinutes('PT2H'), 120);
    assert.equal(isoMinutes('P1DT2H'), 1560);
  });

  test('accepts a bare number of minutes', () => {
    assert.equal(isoMinutes('45'), 45);
  });

  test('returns zero for junk rather than NaN', () => {
    assert.equal(isoMinutes('about an hour'), 0);
    assert.equal(isoMinutes(undefined), 0);
    assert.equal(isoMinutes(null), 0);
  });
});

describe('yields and nutrition', () => {
  test('pulls a serving count out of free text', () => {
    assert.equal(servings('4 servings'), 4);
    assert.equal(servings(6), 6);
    assert.equal(servings(['8 portions']), 8);
    assert.equal(servings('serves a crowd'), 1);
  });

  test('pulls numbers out of unit-suffixed strings', () => {
    assert.equal(numeric('23 g'), 23);
    assert.equal(numeric('450 calories'), 450);
    assert.equal(numeric('12.5g'), 12.5);
    assert.equal(numeric(undefined), 0);
  });
});

describe('text extraction', () => {
  test('decodes HTML entities', () => {
    assert.equal(text('Salt &amp; pepper'), 'Salt & pepper');
    assert.equal(text('Bill&#39;s stew'), "Bill's stew");
  });

  test('unwraps objects and arrays', () => {
    assert.equal(text({ text: 'Chop the onion.' }), 'Chop the onion.');
    assert.equal(text([{ name: 'Soup' }]), 'Soup');
  });
});

describe('instructions', () => {
  test('flattens HowToSection nesting', () => {
    const nested = [
      { '@type': 'HowToSection', itemListElement: [{ '@type': 'HowToStep', text: 'Chop.' }] },
      { '@type': 'HowToStep', text: 'Simmer.' },
    ];
    assert.deepEqual(instructions(nested), ['Chop.', 'Simmer.']);
  });

  test('splits a single paragraph into sentences', () => {
    assert.deepEqual(instructions('Chop the onion. Fry it gently.'), [
      'Chop the onion.',
      'Fry it gently.',
    ]);
  });
});

describe('JSON-LD extraction', () => {
  const page = `
    <html><head>
    <script type="application/javascript">var ignoreMe = 1;</script>
    <script type="application/ld+json">
    {"@context":"https://schema.org","@graph":[
      {"@type":"WebPage","name":"ignore me"},
      {"@type":["Recipe","Thing"],"name":"Test Soup","description":"A soup.",
       "recipeYield":"4 servings","prepTime":"PT10M","cookTime":"PT25M",
       "recipeIngredient":["2 tbsp olive oil","1 onion","500 g carrots"],
       "recipeInstructions":[{"@type":"HowToStep","text":"Chop."},
                             {"@type":"HowToStep","text":"Simmer."}],
       "nutrition":{"@type":"NutritionInformation","calories":"320 calories","proteinContent":"12 g"}}
    ]}
    </script>
    </head><body></body></html>`;

  test('finds only the ld+json blocks', () => {
    const blocks = jsonLdBlocks(page);
    assert.equal(blocks.length, 1);
    assert.ok(!blocks[0].includes('ignoreMe'));
  });

  test('digs the recipe out of an @graph', () => {
    const recipe = findRecipe(jsonLdBlocks(page));
    assert.ok(recipe);
    assert.equal(recipe.name, 'Test Soup');
  });

  test('handles an array @type', () => {
    const recipe = findRecipe(jsonLdBlocks(page));
    assert.ok(Array.isArray(recipe['@type']));
  });

  test('returns null when a page publishes no recipe data', () => {
    assert.equal(findRecipe(jsonLdBlocks('<html><body>just words</body></html>')), null);
  });

  test('survives malformed JSON in one block without losing the others', () => {
    const messy = `
      <script type="application/ld+json">{ not json at all }</script>
      <script type="application/ld+json">{"@type":"Recipe","name":"Second Chance"}</script>`;
    assert.equal(findRecipe(jsonLdBlocks(messy)).name, 'Second Chance');
  });

  test('is not fooled by an uppercase SCRIPT tag', () => {
    const shouty = '<SCRIPT TYPE="application/ld+json">{"@type":"Recipe","name":"Shouty"}</SCRIPT>';
    assert.equal(findRecipe(jsonLdBlocks(shouty)).name, 'Shouty');
  });
});
