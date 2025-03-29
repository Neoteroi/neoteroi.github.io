echo "Fixing links..."

if [ -n "$VERSION" ]; then
  VERSION="/$VERSION"
fi

for i in ./site/*.html
do
  echo "Fixing $i"
  sed -i -E 's,href="\.\.?",href="/blacksheep'$VERSION'/",' $i
  sed -i -E 's,base: ".",base: "/blacksheep'$VERSION'/",' $i
  sed -i -E 's,worker: "assets/,worker: "/blacksheep'$VERSION'/assets/,' $i
  sed -i -E 's,src="\.\/([a-z]+),src="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,href="\.\/([a-z]+),href="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,src="([a-z]+),src="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,href="([a-z]+),href="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,src="([a-z]+),src="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,src="img/,src="/blacksheep'$VERSION'/img/,' $i
  sed -i -E 's,src="../,src="/blacksheep'$VERSION'/,' $i
  sed -i -E 's,href="../,href="/blacksheep'$VERSION'/,' $i
  sed -i -E 's,href="css/,href="/blacksheep'$VERSION'/css/,' $i
  sed -i -E 's,href="img/,href="/blacksheep'$VERSION'/img/,' $i
  sed -i -E 's,href="assets/,href="/blacksheep'$VERSION'/assets/,' $i
  sed -i -E 's,/blacksheep'$VERSION'/https://,https://,' $i
  sed -i -E 's,src="/img,src="/blacksheep'$VERSION'/img,' $i
done


for i in ./site/**/*.html
do
  echo "Fixing $i"
  sed -i -E 's,href="\.\.?",href="/blacksheep'$VERSION'/",' $i
  sed -i -E 's,base: "\.\.",base: "/blacksheep'$VERSION'/",' $i
  sed -i -E 's,worker: "\.\./assets/,worker: "/blacksheep'$VERSION'/assets/,' $i
  sed -i -E 's,src="\.\/([a-z]+),src="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,href="\.\/([a-z]+),href="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,src="([a-z]+),src="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,href="([a-z]+),href="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,src="([a-z]+),src="/blacksheep'$VERSION'/\1,' $i
  sed -i -E 's,src="img/,src="/blacksheep'$VERSION'/img/,' $i
  sed -i -E 's,src="../,src="/blacksheep'$VERSION'/,' $i
  sed -i -E 's,href="../,href="/blacksheep'$VERSION'/,' $i
  sed -i -E 's,href="css/,href="/blacksheep'$VERSION'/css/,' $i
  sed -i -E 's,href="img/,href="/blacksheep'$VERSION'/img/,' $i
  sed -i -E 's,href="assets/,href="/blacksheep'$VERSION'/assets/,' $i
  sed -i -E 's,src="/img,src="/blacksheep'$VERSION'/img,' $i
  sed -i -E 's,/blacksheep'$VERSION'/https://,https://,' $i
done

for i in ./site/**/*.html
do
  echo "Fixing $i"
  sed -i -E 's,/blacksheep'$VERSION'/https://,https://,' $i
  sed -i -E 's,/blacksheep'$VERSION'/http://,http://,' $i
done
