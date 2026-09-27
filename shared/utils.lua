CookingUtils = {}

-- true when a recipe can be cooked at the given cooking type
function CookingUtils.MatchesType(recipe, cookingType)
    local recipeType = recipe.cookingtype or 'all'
    if type(recipeType) == 'table' then
        for _, t in ipairs(recipeType) do
            if t == 'all' or t == cookingType then return true end
        end
        return false
    end
    return recipeType == 'all' or recipeType == cookingType
end

-- true when cookingType is one of Config.CookingTypes
function CookingUtils.IsValidType(cookingType)
    if type(cookingType) ~= 'string' then return false end
    for _, t in pairs(Config.CookingTypes) do
        if t == cookingType then return true end
    end
    return false
end

function CookingUtils.FindRecipeByItem(itemName)
    for index, recipe in ipairs(Config.Cooking) do
        if recipe.receive == itemName then return recipe, index end
    end
end
