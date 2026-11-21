<?php

namespace App\Modules\Recipes\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class StoreRecipeRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'min:3', 'max:100'],
            'description' => ['nullable', 'string', 'max:500'],
            'image_url' => ['nullable', 'string', 'max:500'],
            'category_id' => ['required', 'integer', 'exists:categories,id'],
            'version' => ['required', 'array'],
            ...VersionRules::rules('version.'),
        ];
    }

    public function after(): array
    {
        return [fn (Validator $v) => VersionRules::checkUnits($v, (array) $this->input('version.ingredients', []), 'version.')];
    }
}
