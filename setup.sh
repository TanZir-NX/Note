#!/usr/bin/env bash
set -e

echo "🚀 Initializing GlassNote Project in GitHub Codespaces..."

# Project Root
PROJECT_DIR="$PWD/GlassNoteApp"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 1️⃣ Gradle & Build Config
cat << 'EOF' > settings.gradle
rootProject.name = "GlassNote"
include ':app'
EOF

cat << 'EOF' > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.0' }
}
allprojects { repositories { google(); mavenCentral() } }
EOF

mkdir -p app/src/main/java/com/glassnote/app
mkdir -p app/src/main/res/{layout,drawable,values,mipmap}

cat << 'EOF' > app/build.gradle
plugins { id 'com.android.application' }
android {
    namespace 'com.glassnote.app'
    compileSdk 34
    defaultConfig {
        applicationId "com.glassnote.app"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
        vectorDrawables.useSupportLibrary = true
    }
    buildTypes {
        release { minifyEnabled false }
        debug { minifyEnabled false }
    }
    compileOptions { sourceCompatibility JavaVersion.VERSION_11; targetCompatibility JavaVersion.VERSION_11 }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.recyclerview:recyclerview:1.3.2'
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'com.google.android.material:material:1.11.0'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
}
EOF

# 2️⃣ Gradle Wrapper
mkdir -p gradle/wrapper
cat << 'EOF' > gradle/wrapper/gradle-wrapper.properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

# Download wrapper if missing
if [ ! -f gradlew ]; then
  curl -sLO https://raw.githubusercontent.com/gradle/gradle/master/gradle/wrapper/gradle-wrapper.jar
  cat << 'EOF' > gradlew
#!/usr/bin/env sh
exec java -classpath "$(dirname "$0")/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain "$@"
EOF
  chmod +x gradlew
fi

# 3️⃣ AndroidManifest.xml
cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.glassnote.app">
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="GlassNote"
        android:supportsRtl="true"
        android:theme="@style/Theme.GlassNote">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
        </activity>
        <activity android:name=".NoteEditorActivity" android:exported="false" android:windowSoftInputMode="adjustResize"/>
        <provider android:name="androidx.core.content.FileProvider"
                  android:authorities="com.glassnote.app.provider"
                  android:exported="false" android:grantUriPermissions="true">
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_paths"/>
        </provider>
    </application>
</manifest>
EOF
mkdir -p app/src/main/res/xml
cat << 'EOF' > app/src/main/res/xml/file_paths.xml
<?xml version="1.0" encoding="utf-8"?>
<paths><external-files-path name="shared" path="." /></paths>
EOF

# 4️⃣ Java Source Files
cat << 'JAVAEOF' > app/src/main/java/com/glassnote/app/NoteDatabase.java
package com.glassnote.app;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import java.util.ArrayList;
import java.util.List;

public class NoteDatabase extends SQLiteOpenHelper {
    private static final String DB_NAME = "GlassNote.db";
    private static final int DB_VERSION = 1;
    public static final String TABLE = "notes";
    public static final String ID = "id", TITLE = "title", CONTENT = "content", TIMESTAMP = "timestamp", EXT = "ext";

    public NoteDatabase(Context ctx) { super(ctx, DB_NAME, null, DB_VERSION); }

    @Override public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE " + TABLE + " (" + ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
                TITLE + " TEXT, " + CONTENT + " TEXT, " + TIMESTAMP + " LONG, " + EXT + " TEXT)");
    }
    @Override public void onUpgrade(SQLiteDatabase db, int oldV, int newV) { db.execSQL("DROP TABLE IF EXISTS " + TABLE); onCreate(db); }

    public long addNote(String title, String content, String ext) {
        ContentValues v = new ContentValues(); v.put(TITLE, title); v.put(CONTENT, content); v.put(TIMESTAMP, System.currentTimeMillis()); v.put(EXT, ext);
        return getWritableDatabase().insert(TABLE, null, v);
    }
    public int updateNote(long id, String title, String content) {
        ContentValues v = new ContentValues(); v.put(TITLE, title); v.put(CONTENT, content); v.put(TIMESTAMP, System.currentTimeMillis());
        return getWritableDatabase().update(TABLE, v, ID + "=?", new String[]{String.valueOf(id)});
    }
    public List<NoteModel> getNotes(String query) {
        List<NoteModel> list = new ArrayList<>();
        String sel = query.isEmpty() ? null : TITLE + " LIKE ? OR " + CONTENT + " LIKE ?";
        String[] args = query.isEmpty() ? null : new String[]{"%"+query+"%", "%"+query+"%"};
        try (Cursor c = getReadableDatabase().query(TABLE, null, sel, args, null, null, TIMESTAMP + " DESC")) {
            while (c.moveToNext()) list.add(new NoteModel(c.getLong(0), c.getString(1), c.getString(2), c.getLong(3)));
        }
        return list;
    }
    public void deleteNote(long id) { getWritableDatabase().delete(TABLE, ID + "=?", new String[]{String.valueOf(id)}); }

    public static class NoteModel {
        public long id; public String title, content; public long timestamp;
        public NoteModel(long id, String title, String content, long timestamp) { this.id=id; this.title=title; this.content=content; this.timestamp=timestamp; }
    }
}
JAVAEOF

cat << 'JAVAEOF' > app/src/main/java/com/glassnote/app/MainActivity.java
package com.glassnote.app;
import android.content.Intent;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.View;
import android.widget.SearchView;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import java.util.List;

public class MainActivity extends AppCompatActivity {
    private NoteDatabase db;
    private NoteAdapter adapter;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        db = new NoteDatabase(this);
        RecyclerView rv = findViewById(R.id.rvNotes);
        rv.setLayoutManager(new LinearLayoutManager(this));
        adapter = new NoteAdapter(db.getNotes(""), this);
        rv.setAdapter(adapter);

        SearchView sv = findViewById(R.id.searchView);
        sv.setOnQueryTextListener(new SearchView.OnQueryTextListener() {
            @Override public boolean onQueryTextSubmit(String q) { return true; }
            @Override public boolean onQueryTextChange(String q) { adapter.updateList(db.getNotes(q)); return true; }
        });

        findViewById(R.id.fabAdd).setOnClickListener(v -> startActivity(new Intent(this, NoteEditorActivity.class)));
        findViewById(R.id.fabImport).setOnClickListener(v -> {
            Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT); i.addCategory(Intent.CATEGORY_OPENABLE); i.setType("*/*");
            startActivityForResult(i, 101);
        });
    }

    @Override protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if(req==101 && res==RESULT_OK && data!=null) FileUtils.loadFile(this, data.getData());
    }
    @Override protected void onResume() { super.onResume(); adapter.updateList(db.getNotes("")); }
}
JAVAEOF

cat << 'JAVAEOF' > app/src/main/java/com/glassnote/app/NoteEditorActivity.java
package com.glassnote.app;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.TextWatcher;
import android.widget.EditText;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import com.google.android.material.snackbar.Snackbar;

public class NoteEditorActivity extends AppCompatActivity {
    private long noteId = -1;
    private EditText etTitle, etContent;
    private final Handler autoSave = new Handler(Looper.getMainLooper());
    private final Runnable saveTask = this::saveNote;
    private NoteDatabase db;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_note_editor);
        db = new NoteDatabase(this);
        etTitle = findViewById(R.id.etTitle);
        etContent = findViewById(R.id.etContent);

        noteId = getIntent().getLongExtra("NOTE_ID", -1);
        if(noteId!=-1) {
            var notes = db.getNotes("");
            for(var n : notes) if(n.id==noteId){ etTitle.setText(n.title); etContent.setText(n.content); }
        }

        etTitle.addTextChangedListener(watch());
        etContent.addTextChangedListener(watch());

        findViewById(R.id.btnExport).setOnClickListener(v -> FileUtils.exportNote(this, etTitle.getText().toString(), etContent.getText().toString()));
        findViewById(R.id.btnDelete).setOnClickListener(v -> { if(noteId!=-1) db.deleteNote(noteId); finish(); });
    }

    private TextWatcher watch() {
        return new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int i, int c, int a) {}
            public void onTextChanged(CharSequence s, int i, int b, int c) {}
            public void afterTextChanged(Editable s) { autoSave.removeCallbacks(saveTask); autoSave.postDelayed(saveTask, 1000); }
        };
    }

    private void saveNote() {
        String title = etTitle.getText().toString().trim();
        String content = etContent.getText().toString();
        if(title.isEmpty()) title = "Untitled Note";
        if(noteId==-1) noteId = db.addNote(title, content, "txt");
        else db.updateNote(noteId, title, content);

        NotificationHelper.show(this, "Saved", "Note '" + title + "' saved successfully");
        Snackbar.make(findViewById(android.R.id.content), "Auto-saved ✔", Snackbar.LENGTH_SHORT).show();
    }
}
JAVAEOF

cat << 'JAVAEOF' > app/src/main/java/com/glassnote/app/NoteAdapter.java
package com.glassnote.app;
import android.content.Context;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.recyclerview.widget.RecyclerView;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class NoteAdapter extends RecyclerView.Adapter<NoteAdapter.VH> {
    private List<NoteDatabase.NoteModel> notes; private Context ctx;
    public NoteAdapter(List<NoteDatabase.NoteModel> notes, Context ctx) { this.notes=notes; this.ctx=ctx; }
    public void updateList(List<NoteDatabase.NoteModel> n) { notes=n; notifyDataSetChanged(); }
    public VH onCreateViewHolder(ViewGroup p, int v) { return new VH(LayoutInflater.from(ctx).inflate(R.layout.item_note, p, false)); }
    public void onBindViewHolder(VH h, int p) {
        NoteDatabase.NoteModel n = notes.get(p);
        h.title.setText(n.title); h.content.setText(n.content);
        h.date.setText(new SimpleDateFormat("MMM dd, hh:mm a", Locale.getDefault()).format(new Date(n.timestamp)));
        h.itemView.setOnClickListener(v -> { Intent i = new Intent(ctx, NoteEditorActivity.class); i.putExtra("NOTE_ID", n.id); ctx.startActivity(i); });
    }
    public int getItemCount() { return notes.size(); }
    static class VH extends RecyclerView.ViewHolder { TextView title, content, date; VH(View v) { super(v); title=v.findViewById(R.id.tvTitle); content=v.findViewById(R.id.tvContent); date=v.findViewById(R.id.tvDate); } }
}
JAVAEOF

cat << 'JAVAEOF' > app/src/main/java/com/glassnote/app/FileUtils.java
package com.glassnote.app;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.widget.Toast;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;

public class FileUtils {
    public static void loadFile(Context ctx, Uri uri) {
        try(InputStream in = ctx.getContentResolver().openInputStream(uri)) {
            StringBuilder sb = new StringBuilder();
            try(BufferedReader br = new BufferedReader(new InputStreamReader(in))) {
                String line; while((line=br.readLine())!=null) sb.append(line).append("\n");
            }
            Intent i = new Intent(ctx, NoteEditorActivity.class); i.putExtra("NOTE_TITLE", getFileName(ctx, uri)); i.putExtra("NOTE_CONTENT", sb.toString()); ctx.startActivity(i);
        } catch(Exception e) { Toast.makeText(ctx, "Failed to read file", Toast.LENGTH_SHORT).show(); }
    }
    public static void exportNote(Context ctx, String title, String content) {
        Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT); i.setType("*/*"); i.putExtra(Intent.EXTRA_TITLE, title+".txt");
        i.addCategory(Intent.CATEGORY_OPENABLE); ctx.startActivity(i);
    }
    private static String getFileName(Context ctx, Uri uri) { String r=null; try(Cursor c=ctx.getContentResolver().query(uri,null,null,null,null)){ if(c.moveToFirst()) r=c.getString(c.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME)); } return r!=null?r:"imported.txt"; }
}
JAVAEOF

cat << 'JAVAEOF' > app/src/main/java/com/glassnote/app/NotificationHelper.java
package com.glassnote.app;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;
import androidx.core.app.NotificationCompat;

public class NotificationHelper {
    private static final String CH_ID = "glassnote_channel";
    public static void show(Context ctx, String title, String body) {
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if(Build.VERSION.SDK_INT>=26) nm.createNotificationChannel(new NotificationChannel(CH_ID, "Note Updates", NotificationManager.IMPORTANCE_DEFAULT));
        nm.notify((int)System.currentTimeMillis(), new NotificationCompat.Builder(ctx, CH_ID).setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title).setContentText(body).setAutoCancel(true).build());
    }
}
JAVAEOF

# 5️⃣ Layouts & Drawables
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.coordinatorlayout.widget.CoordinatorLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto" android:layout_width="match_parent" android:layout_height="match_parent"
    android:background="@color/bg_gray">
    <com.google.android.material.appbar.MaterialToolbar android:id="@+id/toolbar" android:layout_width="match_parent" android:layout_height="?attr/actionBarSize"
        android:background="@color/white" app:title="GlassNote" app:titleTextColor="@color/dark"/>
    <SearchView android:id="@+id/searchView" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_margin="12dp" android:layout_marginTop="?attr/actionBarSize"
        android:background="@drawable/glass_card" android:queryHint="Search notes..."/>
    <androidx.recyclerview.widget.RecyclerView android:id="@+id/rvNotes" android:layout_width="match_parent" android:layout_height="match_parent"
        android:paddingTop="120dp" android:clipToPadding="false"/>
    <com.google.android.material.floatingactionbutton.FloatingActionButton android:id="@+id/fabAdd" android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_gravity="bottom|end" android:layout_margin="20dp" android:src="@android:drawable/ic_input_add" app:tint="@color/white"/>
    <com.google.android.material.floatingactionbutton.FloatingActionButton android:id="@+id/fabImport" android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_gravity="bottom|start" android:layout_margin="20dp" android:src="@android:drawable/ic_menu_upload" app:tint="@color/white"/>
</androidx.coordinatorlayout.widget.CoordinatorLayout>
EOF

cat << 'EOF' > app/src/main/res/layout/activity_note_editor.xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent"
    android:orientation="vertical" android:background="@color/white" android:padding="16dp">
    <EditText android:id="@+id/etTitle" android:layout_width="match_parent" android:layout_height="wrap_content" android:hint="Note Title" android:textSize="24sp" android:textStyle="bold" android:background="@null"/>
    <EditText android:id="@+id/etContent" android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1" android:gravity="top" android:hint="Start typing... URLs will auto-detect. Auto-saving enabled." android:background="@null" android:paddingTop="10dp" android:autoLink="web"/>
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:layout_marginTop="10dp">
        <Button android:id="@+id/btnExport" android:layout_width="0dp" android:layout_weight="1" android:layout_height="wrap_content" android:text="Export"/>
        <Button android:id="@+id/btnDelete" android:layout_width="0dp" android:layout_weight="1" android:layout_height="wrap_content" android:text="Delete"/>
    </LinearLayout>
</LinearLayout>
EOF

cat << 'EOF' > app/src/main/res/layout/item_note.xml
<?xml version="1.0" encoding="utf-8"?>
<com.google.android.material.card.MaterialCardView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_margin="8dp" android:background="@drawable/glass_card"
    app:cardCornerRadius="16dp" app:cardElevation="4dp" xmlns:app="http://schemas.android.com/apk/res-auto">
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="12dp">
        <TextView android:id="@+id/tvTitle" android:layout_width="match_parent" android:layout_height="wrap_content" android:textSize="18sp" android:textStyle="bold" android:textColor="@color/dark"/>
        <TextView android:id="@+id/tvContent" android:layout_width="match_parent" android:layout_height="wrap_content" android:maxLines="3" android:layout_marginTop="4dp" android:textColor="#666"/>
        <TextView android:id="@+id/tvDate" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="6dp" android:gravity="end" android:textSize="12sp" android:textColor="#999"/>
    </LinearLayout>
</com.google.android.material.card.MaterialCardView>
EOF

cat << 'EOF' > app/src/main/res/drawable/glass_card.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#F0F4F8"/>
    <corners android:radius="16dp"/>
    <gradient android:startColor="#E8EEF2" android:endColor="#FFFFFF" android:angle="135"/>
    <stroke android:width="1dp" android:color="#D0D8E0"/>
</shape>
EOF

cat << 'JAVAEOF' > app/src/main/res/values/colors.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="white">#FFFFFF</color>
    <color name="bg_gray">#F5F7FA</color>
    <color name="dark">#2C3E50</color>
    <color name="accent">#6C5CE7</color>
</resources>
JAVAEOF

cat << 'JAVAEOF' > app/src/main/res/values/strings.xml
<resources><string name="app_name">GlassNote</string></resources>
JAVAEOF

cat << 'JAVAEOF' > app/src/main/res/values/themes.xml
<resources>
    <style name="Theme.GlassNote" parent="Theme.MaterialComponents.Light.NoActionBar">
        <item name="colorPrimary">@color/accent</item>
        <item name="colorPrimaryVariant">@color/accent</item>
        <item name="colorOnPrimary">@color/white</item>
        <item name="android:statusBarColor">@color/white</item>
    </style>
</resources>
JAVAEOF

# 6️⃣ App Logo (Vector)
cat << 'EOF' > app/src/main/res/mipmap/ic_launcher.xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/white"/>
    <foreground>
        <vector android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
            <path android:fillColor="#6C5CE7" android:pathData="M30,40 L54,24 L78,40 L78,76 L54,92 L30,76 Z"/>
            <path android:fillColor="#FFFFFF" android:pathData="M45,50 L63,50 L63,58 L45,58 Z M45,64 L58,64 L58,72 L45,72 Z"/>
        </vector>
    </foreground>
</adaptive-icon>
EOF

# 7️⃣ Build APK
echo "📦 Installing Android SDK components (if missing)..."
if [ -z "$ANDROID_HOME" ]; then
  echo "⚠️ ANDROID_HOME not set. Assuming GitHub Codespace environment has SDK. Using standard path."
  export ANDROID_HOME="/opt/android-sdk"
fi

echo "🔨 Building APK..."
./gradlew wrapper
./gradlew assembleDebug --no-daemon --console=plain

echo "✅ Build Complete! APK Location:"
ls app/build/outputs/apk/debug/*.apk
mkdir -p ../out
cp app/build/outputs/apk/debug/app-debug.apk ../out/GlassNote_v1.apk
echo "📥 Download ready at: /workspaces/$(basename $PWD)/../out/GlassNote_v1.apk"
