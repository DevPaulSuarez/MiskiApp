<?php

namespace App\Modules\Recipes\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class StoreVersionRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            // Every new version builds on an existing version of the same dish.
            'parent_version_id' => ['required', 'integer',
                Rule::exists('recipe_versions', 'id')->where('recipe_id', $this->route('recipe')->id)],
            ...VersionRules::rules(),
        ];
    }

    public function after(): array
    {
        return [fn (Validator $v) => VersionRules::checkUnits($v, (array) $this->input('ingredients', []))];
    }
}
