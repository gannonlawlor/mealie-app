package mealie.app.db

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class RecipeDatabase(context: Context) : SQLiteOpenHelper(context, "mealie_recipes.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE recipes (
                recipeId TEXT PRIMARY KEY,
                slug TEXT,
                name TEXT,
                recipeData TEXT,
                dateUpdated TEXT
            )
        """)
        db.execSQL("CREATE INDEX idx_slug ON recipes(slug)")
        db.execSQL("CREATE INDEX idx_name ON recipes(name)")
        db.execSQL("""
            CREATE TABLE favorites (
                slug TEXT PRIMARY KEY
            )
        """)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Future migrations go here
    }

    // MARK: - Recipes

    fun saveRecipe(recipeId: String, slug: String?, name: String?, recipeData: String, dateUpdated: String?) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put("recipeId", recipeId)
            put("slug", slug)
            put("name", name)
            put("recipeData", recipeData)
            put("dateUpdated", dateUpdated)
        }
        db.insertWithOnConflict("recipes", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun loadRecipe(slug: String): String? {
        val db = readableDatabase
        val cursor = db.query("recipes", arrayOf("recipeData"), "slug = ?", arrayOf(slug), null, null, null)
        cursor.use {
            if (it.moveToFirst()) {
                return it.getString(0)
            }
        }
        return null
    }

    fun loadAllRecipes(): List<String> {
        val db = readableDatabase
        val cursor = db.query("recipes", arrayOf("recipeData"), null, null, null, null, null)
        val results = mutableListOf<String>()
        cursor.use {
            while (it.moveToNext()) {
                val json = it.getString(0)
                if (json != null) {
                    results.add(json)
                }
            }
        }
        return results
    }

    fun deleteRecipe(recipeId: String) {
        val db = writableDatabase
        db.delete("recipes", "recipeId = ?", arrayOf(recipeId))
    }

    fun recipeCount(): Int {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT COUNT(*) FROM recipes", null)
        cursor.use {
            if (it.moveToFirst()) {
                return it.getInt(0)
            }
        }
        return 0
    }

    // MARK: - Favorites

    fun loadFavorites(): List<String> {
        val db = readableDatabase
        val cursor = db.query("favorites", arrayOf("slug"), null, null, null, null, null)
        val results = mutableListOf<String>()
        cursor.use {
            while (it.moveToNext()) {
                results.add(it.getString(0))
            }
        }
        return results
    }

    fun saveFavorites(slugs: List<String>) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.delete("favorites", null, null)
            for (slug in slugs) {
                val values = ContentValues().apply {
                    put("slug", slug)
                }
                db.insert("favorites", null, values)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun addFavorite(slug: String) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put("slug", slug)
        }
        db.insertWithOnConflict("favorites", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    fun removeFavorite(slug: String) {
        val db = writableDatabase
        db.delete("favorites", "slug = ?", arrayOf(slug))
    }
}
