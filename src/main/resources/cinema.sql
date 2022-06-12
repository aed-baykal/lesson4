drop table if exists films cascade;
create table if not exists films
(
    id                 bigserial primary key,
    name               varchar(255) not null,
    duration           int not null
);

drop table if exists sessions cascade;
create table if not exists sessions
(
    id          bigserial primary key,
    film_id     int not null,
    start_time  timestamp not null,
    price       decimal not null,
    foreign key (film_id) references films (id)
);

create index I_Session_Film_Id on sessions (film_id);
create index I_Session_Start_Time on sessions (start_time);

drop table if exists tickets;
create table if not exists tickets
(
    id          bigserial primary key,
    session_id  int not null,
    place       int not null,
    foreign key (session_id) references sessions (id)
);

create unique index UI_Ticket_Session_Place on tickets (session_id, place);

insert into films (name, duration)
values  ('Артек', 95),
        ('Мой папа - вождь', 100),
        ('Пропавшая', 110),
        ('Одна', 124),
        ('Молодой человек', 105);

insert into sessions (film_id, start_time, price)
select id, timestamp '2022-06-12 17:20:00', 300
from films
where name = 'Пропавшая'
union
select id, '2022-06-12 19:00:00', 300
from films
where name = 'Пропавшая'
union
select id, '2022-06-12 21:35:00', 300
from films
where name = 'Пропавшая'
union
select id, '2022-06-12 11:50:00', 200
from films
where name = 'Одна'
union
select id, '2022-06-12 15:40:00', 250
from films
where name = 'Одна'
union
select id, '2022-06-12 16:50:00', 250
from films
where name = 'Одна'
union
select id, '2022-06-12 17:25:00', 300
from films
where name = 'Мой папа - вождь'
union
select id, '2022-06-12 11:25:00', 200
from films
where name = 'Артек'
union
select id, '2022-06-12 14:40:00', 250
from films
where name = 'Артек'
union
select id, '2022-06-12 16:00:00', 250
from films
where name = 'Артек'
union
select id, '2022-06-12 10:00:00', 200
from films
where name = 'Молодой человек'
union
select id, '2022-06-12 14:30:00', 250
from films
where name = 'Молодой человек'
union
select id, '2022-06-12 19:20:00', 300
from films
where name = 'Молодой человек';

insert into tickets (session_id, place)
select id, 1
from sessions
union
select id, 2
from sessions
union
select id, 3
from sessions
union
select id, 4
from sessions
union
select id, 5
from sessions
union
select id, 6
from sessions
where id = 1
union
select id, 6
from sessions
where id = 3
union
select id, 6
from sessions
where id = 5
union
select id, 6
from sessions
where id = 6
union
select id, 6
from sessions
where id = 8;

-- ошибки в расписании (фильмы накладываются друг на друга), отсортированные по возрастанию времени.
-- Выводить надо колонки «фильм 1», «время начала», «длительность», «фильм 2», «время начала», «длительность».

select f1.name, s1.start_time, f1.duration, f2.name, s2.start_time, f2.duration
from films f1
         inner join sessions s1 on f1.id = s1.film_id
         inner join sessions s2 on s2.start_time >= s1.start_time
    and (f1.duration * interval '1 minute' + s1.start_time) > s2.start_time
         inner join films f2 on f2.id = s2.film_id
where s1.id <> s2.id;

-- перерывы 30 минут и более между фильмами — выводить по уменьшению длительности перерыва.
-- Колонки «фильм 1», «время начала», «длительность», «время начала второго фильма», «длительность перерыва».

select * from (
                  select f1.name, s1.start_time, f1.duration, s2.start_time, (f1.duration * interval '1 minute' + s1.start_time) - s2.start_time as pause
                  from films f1
                           inner join sessions s1 on f1.id = s1.film_id
                           inner join sessions s2 on s2.id =  (select s3.id from sessions s3 where s1.start_time < s3.start_time order by s3.start_time limit 1)
                           inner join films f2 on f2.id = s2.film_id) s
where s.pause > 30 * interval '1 minute'
order by pause desc;

-- список фильмов, для каждого — с указанием общего числа посетителей за все время,
-- среднего числа зрителей за сеанс и общей суммы сборов по каждому фильму (отсортировать по убыванию прибыли).
-- Внизу таблицы должна быть строчка «итого», содержащая данные по всем фильмам сразу.

with result as (select f.name, count(t.id) as ticket_count, cast(count(t.id) / count(distinct s.id) as double precision) as average_clients, sum(s.price) as s_price from films f
                                                                                                                                                                              inner join sessions s on f.id = s.film_id
                                                                                                                                                                              inner join tickets t on s.id = t.session_id
                group by f.name
                order by s_price desc)
select * from result
union all
select 'Итого', sum(result.ticket_count), avg(result.average_clients), sum(result.s_price) from result;

-- число посетителей и кассовые сборы, сгруппированные по времени начала фильма:
-- с 9 до 15, с 15 до 18, с 18 до 21, с 21 до 00:00 (сколько посетителей пришло с 9 до 15 часов и т.д.).

select '9 - 15', count(t.id), sum(s.price) from sessions s
                                                    inner join tickets t on s.id = t.session_id
where extract(hour from s.start_time)::int >= 9 and extract(hour from s.start_time)::int < 15
union all
select '15 - 18', count(t.id), sum(s.price) from sessions s
                                                     inner join tickets t on s.id = t.session_id
where extract(hour from s.start_time)::int >= 15 and extract(hour from s.start_time)::int < 18
union all
select '18 - 21', count(t.id), sum(s.price) from sessions s
                                                     inner join tickets t on s.id = t.session_id
where extract(hour from s.start_time)::int >= 18 and extract(hour from s.start_time)::int < 21
union all
select '21 - 00', count(t.id), sum(s.price) from sessions s
                                                     inner join tickets t on s.id = t.session_id
where extract(hour from s.start_time)::int >= 21;