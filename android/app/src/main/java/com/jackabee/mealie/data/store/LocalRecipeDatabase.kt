package com.jackabee.mealie.data.store

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase

/**
 * Room entity for locally-created ("local mode") recipes. The full recipe is
 * stored as a JSON blob; id/slug/name/orgUrl are extracted into columns for
 * the queries the iOS SQLite store performs.
 */
@Entity(tableName = "local_recipes")
data class LocalRecipeEntity(
    @PrimaryKey val id: String,
    val slug: String?,
    val name: String?,
    val orgUrl: String?,
    val json: String,
)

@Dao
interface LocalRecipeDao {
    @Query("SELECT * FROM local_recipes")
    suspend fun loadAll(): List<LocalRecipeEntity>

    @Query("SELECT * FROM local_recipes WHERE slug = :slug LIMIT 1")
    suspend fun bySlug(slug: String): LocalRecipeEntity?

    @Query("SELECT * FROM local_recipes WHERE orgUrl = :url LIMIT 1")
    suspend fun byOrgURL(url: String): LocalRecipeEntity?

    @Query("SELECT * FROM local_recipes WHERE name LIKE '%' || :name || '%'")
    suspend fun byNameLike(name: String): List<LocalRecipeEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: LocalRecipeEntity)

    @Query("DELETE FROM local_recipes WHERE id = :id")
    suspend fun delete(id: String)

    @Query("SELECT COUNT(*) FROM local_recipes")
    suspend fun count(): Int
}

@Database(entities = [LocalRecipeEntity::class], version = 1, exportSchema = false)
abstract class MealieDatabase : RoomDatabase() {
    abstract fun localRecipeDao(): LocalRecipeDao
}
